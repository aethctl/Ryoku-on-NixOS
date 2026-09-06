package main

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"image/png"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// effectCmdTimeout bounds the external decoders/encoders (magick) that back
// formats Go's stdlib cannot handle, so a stuck child never wedges the daemon.
const effectCmdTimeout = 60 * time.Second

// EffectsList returns the registry entries exactly as the Rust dispatch's
// "list" returned them: one schema map per implemented effect, each carrying a
// category the picker groups by. Only effects with a working renderer appear.
func EffectsList() []map[string]interface{} {
	themeOptions := make([]map[string]interface{}, 0, len(palettes))
	for _, p := range palettes {
		themeOptions = append(themeOptions, map[string]interface{}{"mode": p.name, "label": p.name})
	}
	themeDefault := "Catppuccin"
	if len(palettes) > 0 {
		themeDefault = palettes[0].name
	}

	return []map[string]interface{}{
		withCat(map[string]interface{}{
			"id":          "theme",
			"label":       "Theme recolor",
			"description": "Snap every pixel to its nearest colour in a built-in palette.",
			"params": []map[string]interface{}{
				{"id": "theme", "label": "Theme", "type": "dropdown", "default": themeDefault, "options": themeOptions},
			},
		}, "Colour"),
		withCat(simpleSchema("invert", "Invert", "Invert every colour channel."), "Adjust"),
		withCat(simpleSchema("flip", "Flip", "Flip the image vertically."), "Transform"),
		withCat(simpleSchema("mirror", "Mirror", "Mirror the image horizontally."), "Transform"),
		withCat(simpleSchema("grayscale", "Grayscale", "Drop colour, keep luminance."), "Adjust"),
		withCat(map[string]interface{}{
			"id":          "brightness",
			"label":       "Brightness",
			"description": "Multiply pixel luminance.",
			"params": []map[string]interface{}{
				{"id": "factor", "label": "Factor", "type": "number", "min": 0.1, "max": 10.0, "step": 0.05, "decimals": 2, "default": 1.1},
			},
		}, "Adjust"),
		withCat(map[string]interface{}{
			"id":          "contrast",
			"label":       "Contrast",
			"description": "Stretch or compress the tonal range.",
			"params": []map[string]interface{}{
				{"id": "mode", "label": "Mode", "type": "dropdown", "default": "normal", "options": []map[string]interface{}{
					{"mode": "normal", "label": "Normal"},
					{"mode": "sigmoid", "label": "Sigmoid"},
				}},
				{"id": "factor", "label": "Factor", "type": "number", "min": -100.0, "max": 100.0, "step": 1.0, "decimals": 1, "default": 25.0},
			},
		}, "Adjust"),
		withCat(map[string]interface{}{
			"id":          "saturation",
			"label":       "Saturation",
			"description": "Boost or mute colour intensity.",
			"params": []map[string]interface{}{
				{"id": "percentage", "label": "Percentage", "type": "integer", "min": -100, "max": 100, "step": 1, "default": 25},
			},
		}, "Adjust"),
		withCat(map[string]interface{}{
			"id":          "gamma",
			"label":       "Gamma",
			"description": "Adjust the gamma curve.",
			"params": []map[string]interface{}{
				{"id": "gamma", "label": "Gamma", "type": "number", "min": 0.1, "max": 5.0, "step": 0.05, "decimals": 2, "default": 1.0},
			},
		}, "Adjust"),
		withCat(map[string]interface{}{
			"id":          "pixelate",
			"label":       "Pixelate",
			"description": "Reduce the image to large blocky pixels.",
			"params": []map[string]interface{}{
				{"id": "scale", "label": "Scale", "type": "integer", "min": 2, "max": 100, "step": 1, "default": 15},
			},
		}, "Stylize"),
		withCat(map[string]interface{}{
			"id":          "border",
			"label":       "Border",
			"description": "Draw a coloured frame around the image.",
			"params": []map[string]interface{}{
				{"id": "color", "label": "Colour", "type": "color", "default": "#1a1a1a"},
				{"id": "thickness", "label": "Thickness", "type": "integer", "min": 0, "max": 500, "step": 1, "default": 30},
				{"id": "radius", "label": "Radius", "type": "integer", "min": 0, "max": 500, "step": 1, "default": 0},
			},
		}, "Transform"),
		withCat(map[string]interface{}{
			"id":          "round",
			"label":       "Round corners",
			"description": "Round off the image corners.",
			"params": []map[string]interface{}{
				{"id": "radius", "label": "Radius", "type": "integer", "min": 1, "max": 1000, "step": 1, "default": 60},
			},
		}, "Transform"),
	}
}

func simpleSchema(id, label, description string) map[string]interface{} {
	return map[string]interface{}{
		"id":          id,
		"label":       label,
		"description": description,
		"params":      []map[string]interface{}{},
	}
}

func withCat(schema map[string]interface{}, category string) map[string]interface{} {
	schema["category"] = category
	return schema
}

// effectSuffix mirrors native::suffix: the theme effect encodes its palette name
// so committed files stay distinguishable; every other effect uses its id.
func effectSuffix(effect string, params map[string]interface{}) string {
	if effect == "theme" {
		theme := strParamI(params, "theme", "Catppuccin")
		return "theme-" + strings.ReplaceAll(strings.ToLower(theme), " ", "-")
	}
	return effect
}

func previewDir(cacheDir string) string { return filepath.Join(cacheDir, "effects-preview") }

func previewPath(cacheDir, input, suffix string) (string, error) {
	stem, ext, err := stemExt(input)
	if err != nil {
		return "", err
	}
	ts := time.Now().UnixMilli()
	return filepath.Join(previewDir(cacheDir), fmt.Sprintf("%d-%s-%s.%s", ts, stem, suffix, ext)), nil
}

func libraryPath(input, suffix string) (string, error) {
	stem, ext, err := stemExt(input)
	if err != nil {
		return "", err
	}
	parent := filepath.Dir(input)
	return filepath.Join(parent, "effects", fmt.Sprintf("%s-%s.%s", stem, suffix, ext)), nil
}

// stemExt splits a path into its filename stem and extension (without dot),
// defaulting the extension to png. It errors on paths with no usable filename
// (for example "/"), matching the Rust helpers that returned None there.
func stemExt(p string) (string, string, error) {
	name := filepath.Base(p)
	if name == "" || name == "." || name == string(filepath.Separator) {
		return "", "", fmt.Errorf("input has no stem: %s", p)
	}
	ext := filepath.Ext(name)
	stem := strings.TrimSuffix(name, ext)
	if stem == "" {
		return "", "", fmt.Errorf("input has no stem: %s", p)
	}
	ext = strings.TrimPrefix(ext, ".")
	if ext == "" {
		ext = "png"
	}
	return stem, ext, nil
}

// EffectsPreview renders input through effect into a freshly named file under
// the cache preview dir and returns that path. It runs synchronously; the RPC
// layer owns any goroutine offloading.
func EffectsPreview(cacheDir, input, effect string, params map[string]interface{}) (string, error) {
	suffix := effectSuffix(effect, params)
	output, err := previewPath(cacheDir, input, suffix)
	if err != nil {
		return "", fmt.Errorf("path resolution failed: %w", err)
	}
	if err := renderToFile(effect, input, params, output); err != nil {
		return "", fmt.Errorf("%s failed: %w", effect, err)
	}
	return output, nil
}

// EffectsCommit moves a committed preview into the wallpaper's sibling effects
// directory, mirroring dispatch.rs: try a rename, fall back to copy-through a
// staging file across filesystems.
func EffectsCommit(preview, input, effect string, params map[string]interface{}) (string, error) {
	suffix := effectSuffix(effect, params)
	final, err := libraryPath(input, suffix)
	if err != nil {
		return "", fmt.Errorf("path resolution failed: %w", err)
	}
	if err := commitPreview(preview, final); err != nil {
		return "", fmt.Errorf("commit failed: %w", err)
	}
	return final, nil
}

// EffectsDiscard deletes a preview file; a missing file is not an error, as in
// the Rust discard handler.
func EffectsDiscard(preview string) error {
	err := os.Remove(preview)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func commitPreview(preview, final string) error {
	if parent := filepath.Dir(final); parent != "" {
		if err := os.MkdirAll(parent, 0o755); err != nil {
			return err
		}
	}
	if err := os.Rename(preview, final); err == nil {
		return nil
	}
	staging := final + ".staging"
	if err := copyFile(preview, staging); err != nil {
		return err
	}
	if err := os.Rename(staging, final); err != nil {
		return err
	}
	_ = os.Remove(preview)
	return nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func renderToFile(effect, input string, params map[string]interface{}, output string) error {
	img, err := decodeImage(input)
	if err != nil {
		return err
	}
	out, err := renderEffect(effect, img, params)
	if err != nil {
		return err
	}
	if parent := filepath.Dir(output); parent != "" {
		if err := os.MkdirAll(parent, 0o755); err != nil {
			return err
		}
	}
	return encodeImage(out, output)
}

// decodeImage reads an image into RGBA. Formats the stdlib cannot decode (webp)
// are piped through magick to PNG first.
func decodeImage(path string) (*image.RGBA, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	img, _, decErr := image.Decode(f)
	f.Close()
	if decErr != nil {
		png, mErr := magickToPNG(path)
		if mErr != nil {
			return nil, fmt.Errorf("decode %s: %v (magick fallback: %v)", path, decErr, mErr)
		}
		img, _, decErr = image.Decode(bytes.NewReader(png))
		if decErr != nil {
			return nil, decErr
		}
	}
	return toRGBA(img), nil
}

func magickToPNG(path string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), effectCmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "magick", path, "png:-")
	return cmd.Output()
}

func toRGBA(img image.Image) *image.RGBA {
	if r, ok := img.(*image.RGBA); ok {
		return r
	}
	b := img.Bounds()
	dst := image.NewRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(dst, dst.Bounds(), img, b.Min, draw.Src)
	return dst
}

// encodeImage writes the image using the format implied by the output
// extension. PNG and JPEG go through the stdlib; anything else (webp) is
// encoded to PNG and handed to magick for the final container.
func encodeImage(img *image.RGBA, output string) error {
	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(output), "."))
	switch ext {
	case "png", "":
		return savePNG(img, output)
	case "jpg", "jpeg":
		f, err := os.Create(output)
		if err != nil {
			return err
		}
		if err := jpeg.Encode(f, img, &jpeg.Options{Quality: 95}); err != nil {
			f.Close()
			return err
		}
		return f.Close()
	default:
		var buf bytes.Buffer
		if err := png.Encode(&buf, img); err != nil {
			return err
		}
		ctx, cancel := context.WithTimeout(context.Background(), effectCmdTimeout)
		defer cancel()
		cmd := exec.CommandContext(ctx, "magick", "png:-", output)
		cmd.Stdin = &buf
		return cmd.Run()
	}
}

func savePNG(img *image.RGBA, output string) error {
	f, err := os.Create(output)
	if err != nil {
		return err
	}
	if err := png.Encode(f, img); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

func renderEffect(effect string, img *image.RGBA, params map[string]interface{}) (*image.RGBA, error) {
	switch effect {
	case "theme":
		return applyTheme(img, params)
	case "invert":
		return applyInvert(img), nil
	case "flip":
		return flipVertical(img), nil
	case "mirror":
		return flipHorizontal(img), nil
	case "grayscale":
		return applyGrayscale(img), nil
	case "brightness":
		return applyBrightness(img, params), nil
	case "contrast":
		return applyContrast(img, params), nil
	case "saturation":
		return applySaturation(img, params), nil
	case "gamma":
		return applyGamma(img, params), nil
	case "pixelate":
		return applyPixelate(img, params), nil
	case "border":
		return applyBorder(img, params), nil
	case "round":
		return applyRound(img, params), nil
	default:
		return nil, fmt.Errorf("unknown effect: %s", effect)
	}
}

func applyInvert(img *image.RGBA) *image.RGBA {
	for i := 0; i < len(img.Pix); i += 4 {
		img.Pix[i] = 255 - img.Pix[i]
		img.Pix[i+1] = 255 - img.Pix[i+1]
		img.Pix[i+2] = 255 - img.Pix[i+2]
	}
	return img
}

func flipVertical(img *image.RGBA) *image.RGBA {
	w, h := img.Rect.Dx(), img.Rect.Dy()
	out := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		src := img.Pix[y*img.Stride : y*img.Stride+w*4]
		dstRow := (h - 1 - y) * out.Stride
		copy(out.Pix[dstRow:dstRow+w*4], src)
	}
	return out
}

func flipHorizontal(img *image.RGBA) *image.RGBA {
	w, h := img.Rect.Dx(), img.Rect.Dy()
	out := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		for x := range w {
			si := y*img.Stride + x*4
			di := y*out.Stride + (w-1-x)*4
			copy(out.Pix[di:di+4], img.Pix[si:si+4])
		}
	}
	return out
}

func applyGrayscale(img *image.RGBA) *image.RGBA {
	for i := 0; i < len(img.Pix); i += 4 {
		r := float64(img.Pix[i])
		g := float64(img.Pix[i+1])
		b := float64(img.Pix[i+2])
		l := uint8(clampF(0.2126*r+0.7152*g+0.0722*b, 0, 255))
		img.Pix[i], img.Pix[i+1], img.Pix[i+2] = l, l, l
	}
	return img
}

func applyBrightness(img *image.RGBA, params map[string]interface{}) *image.RGBA {
	factor := floatParam(params, "factor", 1.1)
	for i := 0; i < len(img.Pix); i += 4 {
		for c := range 3 {
			img.Pix[i+c] = uint8(clampF(float64(img.Pix[i+c])*factor, 0, 255))
		}
	}
	return img
}

func applyGamma(img *image.RGBA, params map[string]interface{}) *image.RGBA {
	gamma := math.Max(floatParam(params, "gamma", 1.0), 0.001)
	inv := 1.0 / gamma
	var lut [256]uint8
	for v := range 256 {
		n := math.Pow(float64(v)/255.0, inv)
		lut[v] = uint8(clampF(n*255.0, 0, 255))
	}
	applyRGBLUT(img, &lut)
	return img
}

func applyContrast(img *image.RGBA, params map[string]interface{}) *image.RGBA {
	mode := strParamI(params, "mode", "normal")
	factor := floatParam(params, "factor", 25.0)
	var lut [256]uint8
	if mode == "sigmoid" {
		k := clampF(factor/25.0, -8.0, 8.0)
		sLo := 1.0 / (1.0 + math.Exp(-k*(-0.5)*2.0))
		sHi := 1.0 / (1.0 + math.Exp(-k*(0.5)*2.0))
		span := math.Max(math.Abs(sHi-sLo), 1e-6)
		for v := range 256 {
			n := float64(v) / 255.0
			s := 1.0 / (1.0 + math.Exp(-k*(n-0.5)*2.0))
			normed := (s - sLo) / span
			lut[v] = uint8(clampF(normed*255.0, 0, 255))
		}
	} else {
		f := math.Max((factor+100.0)/100.0, 0.0)
		for v := range 256 {
			out := (float64(v)-127.5)*f + 127.5
			lut[v] = uint8(clampF(out, 0, 255))
		}
	}
	applyRGBLUT(img, &lut)
	return img
}

func applySaturation(img *image.RGBA, params map[string]interface{}) *image.RGBA {
	pct := float64(intParamI(params, "percentage", 25))
	factor := 1.0 + pct/100.0
	for i := 0; i < len(img.Pix); i += 4 {
		r := float64(img.Pix[i])
		g := float64(img.Pix[i+1])
		b := float64(img.Pix[i+2])
		luma := 0.299*r + 0.587*g + 0.114*b
		img.Pix[i] = uint8(clampF(luma+(r-luma)*factor, 0, 255))
		img.Pix[i+1] = uint8(clampF(luma+(g-luma)*factor, 0, 255))
		img.Pix[i+2] = uint8(clampF(luma+(b-luma)*factor, 0, 255))
	}
	return img
}

func applyRGBLUT(img *image.RGBA, lut *[256]uint8) {
	for i := 0; i < len(img.Pix); i += 4 {
		img.Pix[i] = lut[img.Pix[i]]
		img.Pix[i+1] = lut[img.Pix[i+1]]
		img.Pix[i+2] = lut[img.Pix[i+2]]
	}
}

// applyPixelate averages scale-sized blocks, giving the same blocky downscale
// the Rust effect produced by resizing down then up with nearest-neighbour.
func applyPixelate(img *image.RGBA, params map[string]interface{}) *image.RGBA {
	scale := intParamI(params, "scale", 15)
	if scale < 2 {
		scale = 2
	}
	w, h := img.Rect.Dx(), img.Rect.Dy()
	out := image.NewRGBA(image.Rect(0, 0, w, h))
	for by := 0; by < h; by += scale {
		for bx := 0; bx < w; bx += scale {
			bw := scale
			if bx+bw > w {
				bw = w - bx
			}
			bh := scale
			if by+bh > h {
				bh = h - by
			}
			var sr, sg, sb, sa int
			for y := by; y < by+bh; y++ {
				for x := bx; x < bx+bw; x++ {
					i := y*img.Stride + x*4
					sr += int(img.Pix[i])
					sg += int(img.Pix[i+1])
					sb += int(img.Pix[i+2])
					sa += int(img.Pix[i+3])
				}
			}
			n := bw * bh
			r := uint8(sr / n)
			g := uint8(sg / n)
			b := uint8(sb / n)
			a := uint8(sa / n)
			for y := by; y < by+bh; y++ {
				for x := bx; x < bx+bw; x++ {
					i := y*out.Stride + x*4
					out.Pix[i], out.Pix[i+1], out.Pix[i+2], out.Pix[i+3] = r, g, b, a
				}
			}
		}
	}
	return out
}

func applyBorder(img *image.RGBA, params map[string]interface{}) *image.RGBA {
	col := strParamI(params, "color", "#1a1a1a")
	thickness := intParamI(params, "thickness", 30)
	if thickness < 0 {
		thickness = 0
	}
	radius := intParamI(params, "radius", 0)
	if radius < 0 {
		radius = 0
	}
	r, g, b, ok := parseHex(col)
	if !ok {
		r, g, b = 26, 26, 26
	}
	w, h := img.Rect.Dx(), img.Rect.Dy()
	newW, newH := w+thickness*2, h+thickness*2
	out := image.NewRGBA(image.Rect(0, 0, newW, newH))
	draw.Draw(out, out.Bounds(), image.NewUniform(color.RGBA{r, g, b, 255}), image.Point{}, draw.Src)
	draw.Draw(out, image.Rect(thickness, thickness, thickness+w, thickness+h), img, img.Rect.Min, draw.Over)
	if radius > 0 {
		applyCornerMask(out, radius)
	}
	return out
}

func applyRound(img *image.RGBA, params map[string]interface{}) *image.RGBA {
	radius := intParamI(params, "radius", 60)
	if radius < 1 {
		radius = 1
	}
	applyCornerMask(img, radius)
	return img
}

func applyCornerMask(img *image.RGBA, radius int) {
	r := float64(radius)
	w, h := img.Rect.Dx(), img.Rect.Dy()
	if radius >= w/2 || radius >= h/2 {
		return
	}
	type corner struct {
		x0, y0 int
		cx, cy float64
	}
	corners := []corner{
		{0, 0, r, r},
		{w - radius, 0, float64(w - radius), r},
		{0, h - radius, r, float64(h - radius)},
		{w - radius, h - radius, float64(w - radius), float64(h - radius)},
	}
	for _, c := range corners {
		for dy := range radius {
			for dx := range radius {
				px := c.x0 + dx
				py := c.y0 + dy
				fx := float64(px) + 0.5
				fy := float64(py) + 0.5
				dist := math.Sqrt((fx-c.cx)*(fx-c.cx) + (fy-c.cy)*(fy-c.cy))
				var alpha float64
				switch {
				case dist <= r-0.5:
					alpha = 1.0
				case dist >= r+0.5:
					alpha = 0.0
				default:
					alpha = (r + 0.5) - dist
				}
				if alpha < 1.0 {
					i := py*img.Stride + px*4
					img.Pix[i+3] = uint8(float64(img.Pix[i+3]) * alpha)
				}
			}
		}
	}
}

// applyTheme snaps every pixel to a smoothed nearest-palette colour via a
// 32x32x32 lookup table, matching native.rs build_palette_lut (sigma 50).
func applyTheme(img *image.RGBA, params map[string]interface{}) (*image.RGBA, error) {
	name := strParamI(params, "theme", "Catppuccin")
	pal, ok := themeLookup(name)
	if !ok {
		return nil, fmt.Errorf("unknown theme: %s", name)
	}
	if len(pal) == 0 {
		return nil, fmt.Errorf("theme %s has no colours", name)
	}
	lut := buildPaletteLUT(pal, 50.0)
	for i := 0; i < len(img.Pix); i += 4 {
		r := int(img.Pix[i]) >> 3
		g := int(img.Pix[i+1]) >> 3
		b := int(img.Pix[i+2]) >> 3
		e := lut[(r<<10)|(g<<5)|b]
		img.Pix[i], img.Pix[i+1], img.Pix[i+2] = e[0], e[1], e[2]
	}
	return img, nil
}

func buildPaletteLUT(pal [][3]uint8, sigma float64) [][3]uint8 {
	const n = 32
	twoSigmaSq := 2.0 * sigma * sigma
	type fcol struct{ r, g, b float64 }
	cols := make([]fcol, len(pal))
	for i, c := range pal {
		cols[i] = fcol{float64(c[0]), float64(c[1]), float64(c[2])}
	}
	lut := make([][3]uint8, n*n*n)
	for idx := range n * n * n {
		i := idx >> 10
		j := (idx >> 5) & 0x1f
		k := idx & 0x1f
		tr := float64(i*8 + 4)
		tg := float64(j*8 + 4)
		tb := float64(k*8 + 4)
		var numR, numG, numB, den float64
		for _, c := range cols {
			dr := tr - c.r
			dg := tg - c.g
			db := tb - c.b
			d2 := dr*dr + dg*dg + db*db
			w := math.Exp(-d2 / twoSigmaSq)
			numR += c.r * w
			numG += c.g * w
			numB += c.b * w
			den += w
		}
		invD := 1.0 / math.Max(den, 1e-30)
		lut[idx] = [3]uint8{
			uint8(clampF(numR*invD, 0, 255)),
			uint8(clampF(numG*invD, 0, 255)),
			uint8(clampF(numB*invD, 0, 255)),
		}
	}
	return lut
}

func parseHex(s string) (uint8, uint8, uint8, bool) {
	h := strings.TrimPrefix(s, "#")
	if len(h) != 6 {
		return 0, 0, 0, false
	}
	r, err1 := strconv.ParseUint(h[0:2], 16, 8)
	g, err2 := strconv.ParseUint(h[2:4], 16, 8)
	b, err3 := strconv.ParseUint(h[4:6], 16, 8)
	if err1 != nil || err2 != nil || err3 != nil {
		return 0, 0, 0, false
	}
	return uint8(r), uint8(g), uint8(b), true
}

func clampF(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// JSON numbers decode to float64; these readers accept that and coerce.
func floatParam(p map[string]interface{}, key string, def float64) float64 {
	if v, ok := p[key]; ok {
		if f, ok := v.(float64); ok {
			return f
		}
	}
	return def
}

func intParamI(p map[string]interface{}, key string, def int) int {
	if v, ok := p[key]; ok {
		switch n := v.(type) {
		case float64:
			return int(n)
		case int:
			return n
		}
	}
	return def
}

func strParamI(p map[string]interface{}, key, def string) string {
	if v, ok := p[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return def
}
