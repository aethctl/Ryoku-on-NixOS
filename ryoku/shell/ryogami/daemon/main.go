package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

// unmarshalStrict is json.Unmarshal with the error surfaced (helper shared by
// the verb layer; declared here to keep verbs.go free of encoding imports).
func unmarshalStrict(body string, into interface{}) error {
	return json.Unmarshal([]byte(body), into)
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 || args[0] == "daemon" {
		if err := runDaemon(); err != nil {
			fmt.Fprintln(os.Stderr, "ryogami:", err)
			os.Exit(1)
		}
		return
	}
	// Client mode: forward `wallpaper ...` / `depth ...` verb lines to the
	// daemon and print any reply that is not a bare ok, exactly like the Rust
	// CLI this replaces (keybinds and scripts shell out to it).
	switch args[0] {
	case "wallpaper", "depth":
		line := strings.Join(args, " ")
		reply, err := sendLine(line)
		if err != nil {
			fmt.Fprintln(os.Stderr, "ryogami:", err)
			os.Exit(1)
		}
		if strings.HasPrefix(reply, "err") {
			fmt.Fprintln(os.Stderr, "ryogami:", strings.TrimPrefix(reply, "err "))
			os.Exit(1)
		}
		if reply != "" && reply != "ok" {
			fmt.Println(reply)
		}
	default:
		fmt.Fprintln(os.Stderr, "usage: ryogami [daemon | wallpaper <mode> ... | depth <set|clear> ...]")
		os.Exit(2)
	}
}

func sendLine(line string) (string, error) {
	conn, err := net.DialTimeout("unix", socketPath(), 2*time.Second)
	if err != nil {
		return "", fmt.Errorf("daemon not reachable at %s (is `ryogami` running?)", socketPath())
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(30 * time.Second))
	if _, err := fmt.Fprintf(conn, "%s\n", line); err != nil {
		return "", err
	}
	reply, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil && reply == "" {
		return "", err
	}
	return strings.TrimSpace(reply), nil
}
