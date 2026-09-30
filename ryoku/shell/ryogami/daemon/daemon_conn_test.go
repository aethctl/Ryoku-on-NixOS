package main

import (
	"bufio"
	"net"
	"strings"
	"sync"
	"testing"
	"time"
)

// The picker opens and closes on events that share its request connection. A request
// still running (here a settings watcher that has not finished) must not hold them back.
func TestEventsFlowWhileRequestRuns(t *testing.T) {
	d := newSettingsDaemon(t)
	entered := make(chan struct{})
	release := make(chan struct{})
	var releaseOnce sync.Once
	unblock := func() { releaseOnce.Do(func() { close(release) }) }
	saved := settingWatchers
	t.Cleanup(func() {
		unblock()
		settingWatchers = saved
	})
	watchSetting("selector.livePreview", func(*daemon, string, interface{}) {
		close(entered)
		<-release
	})

	server, client := net.Pipe()
	t.Cleanup(func() { client.Close() })
	go func() {
		defer server.Close()
		d.handle(server)
	}()
	lines := make(chan string, 16)
	go func() {
		sc := bufio.NewScanner(client)
		for sc.Scan() {
			lines <- sc.Text()
		}
		close(lines)
	}()
	send := func(line string) {
		t.Helper()
		if _, err := client.Write([]byte(line + "\n")); err != nil {
			t.Fatal(err)
		}
	}
	next := func(what string) string {
		t.Helper()
		select {
		case l := <-lines:
			return l
		case <-time.After(3 * time.Second):
			t.Fatalf("timed out waiting for %s", what)
			return ""
		}
	}

	send(`{"id":1,"method":"subscribe"}`)
	if l := next("the subscribe reply"); !strings.Contains(l, `"subscribed":true`) {
		t.Fatalf("subscribe reply = %s", l)
	}
	send(`{"id":2,"method":"settings.set","params":{"values":{"selector.livePreview":false}}}`)
	select {
	case <-entered:
	case <-time.After(3 * time.Second):
		t.Fatal("the settings watcher never ran")
	}

	d.broadcast("ryogami.wall.toggle", map[string]interface{}{})
	for {
		l := next("the toggle event")
		if strings.Contains(l, "ryogami.wall.toggle") {
			break
		}
		if strings.Contains(l, `"id":2`) {
			t.Fatalf("settings.set answered before its watcher finished: %s", l)
		}
	}

	unblock()
	for {
		if l := next("the settings.set reply"); strings.Contains(l, `"id":2`) {
			break
		}
	}
}
