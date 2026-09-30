package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
)

// Transcodes are GPU work, so they run on the strongest GPU: NVDEC and NVENC when the
// NVIDIA driver is up (its VA-API shim cannot encode), else VA-API on the AMD card with
// the most VRAM. A failed attempt falls through to the next, ending on a niced CPU encode;
// a machine with NVIDIA never falls back onto its integrated GPU.

type videoEncoder struct {
	nvenc bool
	vaapi string // AMD render node; unused when NVENC is available
}

type transcodeSpec struct {
	src, dst string
	fps      int
	maxWidth int  // the clip is scaled down to this, never up
	qp       int  // constant QP on the GPU encoders
	crf      int  // libx264 CRF on the CPU
	audio    bool // keep a stereo AAC track
}

var (
	videoEncoderOnce sync.Once
	videoEncoderPick videoEncoder
)

func pickVideoEncoder() videoEncoder {
	videoEncoderOnce.Do(func() {
		encoders, _ := exec.Command("ffmpeg", "-hide_banner", "-encoders").Output()
		videoEncoderPick = detectVideoEncoder("/sys/class/drm",
			fileExists("/proc/driver/nvidia/version"),
			fileExists("/usr/lib/dri/radeonsi_drv_video.so"),
			string(encoders))
	})
	return videoEncoderPick
}

func detectVideoEncoder(drm string, nvidia, radeonsi bool, encoders string) videoEncoder {
	if nvidia {
		// The NVIDIA card is the strong one: without NVENC the CPU encodes, not the iGPU.
		return videoEncoder{nvenc: ffmpegLists(encoders, "h264_nvenc")}
	}
	if radeonsi && ffmpegLists(encoders, "h264_vaapi") {
		return videoEncoder{vaapi: strongestAMDRenderNode(drm)}
	}
	return videoEncoder{}
}

func ffmpegLists(encoders, name string) bool {
	for _, line := range strings.Split(encoders, "\n") {
		if f := strings.Fields(line); len(f) > 1 && f[1] == name {
			return true
		}
	}
	return false
}

// strongestAMDRenderNode is the amdgpu render node with the most VRAM: on a machine with
// both, the discrete card rather than the APU's small carve-out.
func strongestAMDRenderNode(drm string) string {
	nodes, _ := filepath.Glob(filepath.Join(drm, "renderD*"))
	best, bestVRAM := "", int64(-1)
	for _, n := range nodes {
		driver, err := os.Readlink(filepath.Join(n, "device", "driver"))
		if err != nil || filepath.Base(driver) != "amdgpu" {
			continue
		}
		vram, _ := strconv.ParseInt(readTrimmed(filepath.Join(n, "device", "mem_info_vram_total")), 10, 64)
		if vram > bestVRAM {
			best, bestVRAM = "/dev/dri/"+filepath.Base(n), vram
		}
	}
	return best
}

func (e videoEncoder) attempts(s transcodeSpec) [][]string {
	width := fmt.Sprintf("trunc(min(%d,iw)/2)*2", s.maxWidth)
	rate := "fps=" + strconv.Itoa(s.fps)
	audio := []string{"-an"}
	if s.audio {
		audio = []string{"-c:a", "aac", "-b:a", "128k", "-ac", "2"}
	}
	qp := strconv.Itoa(s.qp)
	nvenc := []string{"-c:v", "h264_nvenc", "-preset", "p4", "-rc", "constqp", "-qp", qp, "-bf", "0"}
	run := func(pre []string, filter string, codec []string) []string {
		argv := append([]string{"ffmpeg", "-y", "-v", "error"}, pre...)
		argv = append(argv, "-i", s.src, "-vf", filter)
		argv = append(argv, codec...)
		return append(append(argv, audio...), s.dst)
	}

	var runs [][]string
	switch {
	case e.nvenc:
		runs = append(runs,
			run([]string{"-hwaccel", "cuda", "-hwaccel_output_format", "cuda"},
				rate+",scale_cuda=w='"+width+"':h=-2:format=nv12", nvenc),
			// Formats NVDEC cannot decode (GIF, some profiles) still encode on the NVIDIA card.
			run(nil, rate+",scale='"+width+"':-2:flags=bicubic,format=nv12", nvenc))
	case e.vaapi != "":
		runs = append(runs,
			run([]string{"-hwaccel", "vaapi", "-hwaccel_device", e.vaapi, "-hwaccel_output_format", "vaapi"},
				rate+",scale_vaapi=w='"+width+"':h=-2:format=nv12",
				[]string{"-c:v", "h264_vaapi", "-qp", qp, "-bf", "0"}))
	}
	cpu := run(nil, rate+",scale='"+width+"':-2:flags=bicubic",
		[]string{"-c:v", "libx264", "-preset", "veryfast", "-crf", strconv.Itoa(s.crf), "-bf", "0",
			"-threads", "4", "-pix_fmt", "yuv420p"})
	return append(runs, append([]string{"nice", "-n", "19"}, cpu...))
}

// transcodeH264 writes s.dst, trying each encoder in turn; the error carries the last
// attempt's output.
func transcodeH264(ctx context.Context, s transcodeSpec) error {
	var last error
	for _, argv := range pickVideoEncoder().attempts(s) {
		out, err := exec.CommandContext(ctx, argv[0], argv[1:]...).CombinedOutput()
		if err == nil && fileExists(s.dst) {
			return nil
		}
		_ = os.Remove(s.dst)
		last = fmt.Errorf("%v: %s", err, strings.TrimSpace(string(out)))
		if ctx.Err() != nil {
			return ctx.Err()
		}
	}
	return last
}
