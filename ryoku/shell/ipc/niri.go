package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"time"
)

type niriCompositor struct {
	socket string
}

func (n niriCompositor) Name() string {
	return compositorNiri
}

func (n niriCompositor) Identity() string {
	if n.socket == "" {
		return ""
	}
	return compositorNiri + ":" + n.socket
}

func (n niriCompositor) Prepare() {}

func (n niriCompositor) Start(d *daemon) {
	go d.watchNiri(n.socket)
}

func openNiriEventStream(path string) (net.Conn, *bufio.Reader, error) {
	conn, err := net.DialTimeout("unix", path, 500*time.Millisecond)
	if err != nil {
		return nil, nil, err
	}

	_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err := fmt.Fprintln(conn, `"EventStream"`); err != nil {
		conn.Close()
		return nil, nil, err
	}

	reader := bufio.NewReader(conn)
	line, err := reader.ReadBytes('\n')
	if err != nil {
		conn.Close()
		return nil, nil, err
	}

	var reply map[string]json.RawMessage
	if err := json.Unmarshal(line, &reply); err != nil {
		conn.Close()
		return nil, nil, err
	}

	ok, exists := reply["Ok"]
	if !exists || string(ok) != `"Handled"` {
		conn.Close()
		return nil, nil, fmt.Errorf("niri rejected event stream")
	}

	_ = conn.SetDeadline(time.Time{})
	return conn, reader, nil
}

func (d *daemon) watchNiri(path string) {
	backoff := 150 * time.Millisecond

	for {
		select {
		case <-d.quit:
			return
		default:
		}

		conn, reader, err := openNiriEventStream(path)
		if err != nil {
			select {
			case <-d.quit:
				return
			case <-time.After(backoff):
			}
			backoff = capDur(backoff*2, 5*time.Second)
			continue
		}

		backoff = 150 * time.Millisecond
		done := make(chan struct{})
		go func() {
			select {
			case <-d.quit:
				conn.Close()
			case <-done:
			}
		}()

		scanner := bufio.NewScanner(reader)
		scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)
		for scanner.Scan() {
			if !json.Valid(scanner.Bytes()) {
				break
			}
		}

		close(done)
		conn.Close()
	}
}
