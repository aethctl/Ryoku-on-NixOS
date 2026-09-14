package wm

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
	"syscall"
)

// Client resolves the provider binary once and speaks the verbs to it. Shared so
// the contract lives in one place: five hand-rolled JSON callers would be five
// copies, and the first schema change would leave four wrong.

// ErrNoProvider is not fatal. The Hub must still open on a box whose provider
// package was removed, so callers treat it as "no compositor features".
var ErrNoProvider = errors.New("no window manager provider available")

// ErrUnsupported is a different message to a user than ErrNoProvider: the
// provider is there, the compositor just cannot do that.
var ErrUnsupported = errors.New("window manager does not support this action")

// Safe for concurrent use. Caps is cached for the process lifetime: a
// compositor does not gain features while running, and the keybind path cannot
// afford a fork to re-ask.
type Client struct {
	detection Detection
	bin       string

	once sync.Once
	caps Caps
	err  error
}

// Open resolves the active provider without running it, so constructing one in
// a daemon's init never blocks on a compositor that is still coming up.
func Open() *Client {
	d := Detect()
	c := &Client{detection: d}
	if d.Name != "" {
		c.bin = "ryoku-wm-" + d.Name
	}
	return c
}

// OpenNamed targets a compositor the caller is not in: the installer preparing a
// target, and `ryoku wm use <name>` previewing a switch.
func OpenNamed(name string) *Client {
	return &Client{
		detection: Detection{Name: name, Live: false, Source: "explicit"},
		bin:       "ryoku-wm-" + name,
	}
}

func (c *Client) Detection() Detection { return c.detection }

func (c *Client) Available() bool {
	if c.bin == "" {
		return false
	}
	_, err := exec.LookPath(c.bin)
	return err == nil
}

// Caps probes at most once. A failed probe yields a zero Caps, so every Has
// reads false rather than assuming Hyprland's feature set.
func (c *Client) Caps() (Caps, error) {
	c.once.Do(func() {
		if c.bin == "" {
			c.err = ErrNoProvider
			return
		}
		out, err := c.run("caps")
		if err != nil {
			c.err = err
			return
		}
		c.err = json.Unmarshal(out, &c.caps)
	})
	return c.caps, c.err
}

// Can is the gate before offering an affordance. False on a missing provider
// too, which is what a caller wants.
func (c *Client) Can(want Capability) bool {
	caps, err := c.Caps()
	if err != nil {
		return false
	}
	return caps.Has(want)
}

// Act checks the capability first, so an unsupported action is a typed error
// rather than a fork that exits zero having done nothing.
func (c *Client) Act(a Action, args ...string) error {
	if c.bin == "" {
		return ErrNoProvider
	}
	if need := a.Capability(); need != "" && !c.Can(need) {
		return fmt.Errorf("%w: %s", ErrUnsupported, a)
	}
	argv := append([]string{"act", string(a)}, args...)
	_, err := c.run(argv...)
	return err
}

// ActOutput is Act for the actions that answer with a value, so a caller can
// restore exactly what it overrode.
func (c *Client) ActOutput(a Action, args ...string) (string, error) {
	if c.bin == "" {
		return "", ErrNoProvider
	}
	if need := a.Capability(); need != "" && !c.Can(need) {
		return "", fmt.Errorf("%w: %s", ErrUnsupported, a)
	}
	out, err := c.run(append([]string{"act", string(a)}, args...)...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

// Apply hands over the neutral store by path, not stdin, so the provider can
// re-read it during a long apply and the call works from a hook.
func (c *Client) Apply(storePath string) (ApplyReport, error) {
	var rep ApplyReport
	if c.bin == "" {
		return rep, ErrNoProvider
	}
	out, err := c.run("apply", storePath)
	if err != nil {
		return rep, err
	}
	if err := json.Unmarshal(out, &rep); err != nil {
		return rep, fmt.Errorf("%s apply: %w", c.bin, err)
	}
	return rep, nil
}

// DryRun asks a provider what it could not honour if the store were applied to
// it, and writes nothing. Ungated, unlike Preview: the question is answerable
// by any provider, and it is how `ryoku wm use` and the Hub tell a user what a
// switch would cost BEFORE the target owns the config. Calling Apply here would
// author the target compositor's config as a side effect of asking.
func (c *Client) DryRun(storePath string) (ApplyReport, error) {
	var rep ApplyReport
	if c.bin == "" {
		return rep, ErrNoProvider
	}
	out, err := c.run("apply", storePath, "--preview")
	if err != nil {
		return rep, err
	}
	if err := json.Unmarshal(out, &rep); err != nil {
		return rep, fmt.Errorf("%s dry run: %w", c.bin, err)
	}
	return rep, nil
}

// Preview pushes the store to the live session without writing any config, for
// the Hub's appearance sliders. Gated on CapLiveConfigEval: a compositor whose
// config is file-only cannot preview, and the Hub then applies on save.
func (c *Client) Preview(storePath string) (ApplyReport, error) {
	var rep ApplyReport
	if c.bin == "" {
		return rep, ErrNoProvider
	}
	if !c.Can(CapLiveConfigEval) {
		return rep, fmt.Errorf("%w: preview", ErrUnsupported)
	}
	out, err := c.run("apply", storePath, "--preview")
	if err != nil {
		return rep, err
	}
	if err := json.Unmarshal(out, &rep); err != nil {
		return rep, fmt.Errorf("%s preview: %w", c.bin, err)
	}
	return rep, nil
}

// State is one full read, for callers that ask a single question and exit.
func (c *Client) State() (Snapshot, error) {
	var snap Snapshot
	if c.bin == "" {
		return snap, ErrNoProvider
	}
	out, err := c.run("state")
	if err != nil {
		return snap, err
	}
	if err := json.Unmarshal(out, &snap); err != nil {
		return snap, fmt.Errorf("%s state: %w", c.bin, err)
	}
	return snap, nil
}

// Defaults is the provider's default subtree of the neutral store. Raw JSON
// because defaults are the provider's shape, and the Hub merges rather than
// reasons about them.
func (c *Client) Defaults() ([]byte, error) {
	if c.bin == "" {
		return nil, ErrNoProvider
	}
	return c.run("defaults")
}

// Schema is the provider's exclusive settings rows, in the shape the Hub's
// settings renderer consumes. Each row stays raw: the field set is the
// provider's to define (a control the Hub knows how to draw), and the Hub emits
// it back untouched. Empty with no error when a provider declares none, so a
// compositor with no exclusive settings simply contributes no window-manager
// page rows.
func (c *Client) Schema() ([]json.RawMessage, error) {
	if c.bin == "" {
		return nil, ErrNoProvider
	}
	out, err := c.run("schema")
	if err != nil {
		return nil, err
	}
	out = bytes.TrimSpace(out)
	if len(out) == 0 {
		return []json.RawMessage{}, nil
	}
	var rows []json.RawMessage
	if err := json.Unmarshal(out, &rows); err != nil {
		return nil, fmt.Errorf("schema: %w", err)
	}
	return rows, nil
}

// Binds is the provider's compositor-exclusive keybinds, in the shape the
// keybind legend consumes: each row a {chord, desc} for a behaviour that has no
// place in the shared Ryoku bind set, so the cheatsheet can list it under the
// compositor's own name. The store path resolves the user's rebinds and unbinds
// the way apply does, so the list reflects the chords actually emitted, never a
// static default a user has displaced. Empty with no error when a provider adds
// none, so a compositor that only speaks the shared binds contributes no section.
func (c *Client) Binds(storePath string) ([]json.RawMessage, error) {
	if c.bin == "" {
		return nil, ErrNoProvider
	}
	out, err := c.run("binds", storePath)
	if err != nil {
		return nil, err
	}
	out = bytes.TrimSpace(out)
	if len(out) == 0 {
		return []json.RawMessage{}, nil
	}
	var rows []json.RawMessage
	if err := json.Unmarshal(out, &rows); err != nil {
		return nil, fmt.Errorf("binds: %w", err)
	}
	return rows, nil
}

// Session is the wayland-session desktop-entry body for this provider, for the
// installer and the greeter setup to write when the compositor package ships
// none. Raw bytes: the entry is the provider's to author.
func (c *Client) Session() ([]byte, error) {
	if c.bin == "" {
		return nil, ErrNoProvider
	}
	return c.run("session")
}

// Plugins returns raw JSON: the inventory shape is the provider's to define and
// the only consumer reports what it is told.
func (c *Client) Plugins(args ...string) ([]byte, error) {
	if c.bin == "" {
		return nil, ErrNoProvider
	}
	if !c.Can(CapPlugins) {
		return nil, fmt.Errorf("%w: plugins", ErrUnsupported)
	}
	return c.run(append([]string{"plugins"}, args...)...)
}

// Watch streams frames until ctx is done or the provider exits. onFrame runs on
// the reader goroutine, so a consumer doing real work should hand off.
//
// The caller owns restart policy: a compositor restart must not leave a
// permanently cold cache.
func (c *Client) Watch(ctx context.Context, onFrame func(Frame)) error {
	return c.WatchKinds(ctx, nil, onFrame)
}

// WatchKinds is Watch limited to the frame kinds the caller uses. Narrowing
// matters: the provider only reads what it has to emit, so a consumer that
// wants outputs does not make the compositor answer for windows on every
// window event.
func (c *Client) WatchKinds(ctx context.Context, kinds []FrameKind, onFrame func(Frame)) error {
	if c.bin == "" {
		return ErrNoProvider
	}
	argv := []string{"watch"}
	for _, k := range kinds {
		argv = append(argv, string(k))
	}
	cmd := exec.CommandContext(ctx, c.bin, argv...)
	// Die with the parent. A watch child outlives a consumer that is restarted
	// or killed otherwise, and every restart would leave another one streaming
	// into a closed pipe and re-querying the compositor.
	cmd.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGTERM}
	cmd.Stderr = os.Stderr
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return err
	}
	scan := bufio.NewScanner(stdout)
	// Frames carry full lists; a busy session overruns the 64 KiB default and a
	// truncated frame would read as "windows closed".
	scan.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for scan.Scan() {
		line := bytes.TrimSpace(scan.Bytes())
		if len(line) == 0 {
			continue
		}
		var f Frame
		if err := json.Unmarshal(line, &f); err != nil {
			// One bad frame goes stale for that update only; the next repairs it.
			continue
		}
		onFrame(f)
	}
	waitErr := cmd.Wait()
	if ctx.Err() != nil {
		return nil
	}
	if err := scan.Err(); err != nil {
		return err
	}
	return waitErr
}

// run folds stderr into the error so a provider diagnostic reaches the caller's
// log instead of being swallowed.
func (c *Client) run(args ...string) ([]byte, error) {
	cmd := exec.Command(c.bin, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			return nil, fmt.Errorf("%s %s: %w", c.bin, strings.Join(args, " "), err)
		}
		return nil, fmt.Errorf("%s %s: %w: %s", c.bin, strings.Join(args, " "), err, msg)
	}
	return stdout.Bytes(), nil
}

// ApplyOutputs hands the provider an output layout the display editor built. It
// persists to the compositor's config and applies live where the compositor
// allows, and reports anything it could not express the same way Apply does. The
// layout is passed by path, like Apply, so a long apply can re-read it. Gated on
// CapMonitorConfig: a provider that cannot configure outputs has no display page.
func (c *Client) ApplyOutputs(layoutPath string) (ApplyReport, error) {
	var rep ApplyReport
	if c.bin == "" {
		return rep, ErrNoProvider
	}
	if !c.Can(CapMonitorConfig) {
		return rep, fmt.Errorf("%w: output layout", ErrUnsupported)
	}
	out, err := c.run("outputs", layoutPath)
	if err != nil {
		return rep, err
	}
	if err := json.Unmarshal(out, &rep); err != nil {
		return rep, fmt.Errorf("%s outputs: %w", c.bin, err)
	}
	return rep, nil
}
