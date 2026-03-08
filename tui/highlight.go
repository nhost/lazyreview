package tui

import (
	"fmt"
	"strings"

	"github.com/alecthomas/chroma/v2"
	"github.com/alecthomas/chroma/v2/lexers"
	"github.com/alecthomas/chroma/v2/styles"
	"github.com/nhost/lazyreview/diff"
)

// highlighter tokenizes diff lines using chroma and caches the results per file.
type highlighter struct {
	cache map[string][]string // file path -> highlighted lines
	style *chroma.Style
}

// newHighlighter creates a highlighter with the dracula chroma style.
func newHighlighter() *highlighter {
	return &highlighter{
		cache: make(map[string][]string),
		style: styles.Get("dracula"),
	}
}

// clear invalidates the entire highlight cache.
func (h *highlighter) clear() {
	h.cache = make(map[string][]string)
}

// highlightFile tokenizes all lines in a diff file and returns cached results.
// Returns nil if no lexer matches the file path.
func (h *highlighter) highlightFile(f *diff.File, path string) []string {
	if f == nil {
		return nil
	}

	if cached, ok := h.cache[path]; ok {
		return cached
	}

	lexer := lexers.Match(path)
	if lexer == nil {
		return nil
	}

	lexer = chroma.Coalesce(lexer)

	var lines []string
	for _, hunk := range f.Hunks {
		// blank entry for the hunk header line
		lines = append(lines, "")

		for _, line := range hunk.Lines {
			lines = append(lines, h.highlightLine(lexer, line.Content))
		}
	}

	h.cache[path] = lines

	return lines
}

// highlightLine tokenizes a single line and returns an ANSI-colored string.
func (h *highlighter) highlightLine(lexer chroma.Lexer, content string) string {
	// Strip the diff prefix (+/-/ ) for tokenization
	raw := content
	if len(raw) > 0 {
		switch raw[0] {
		case '+', '-', ' ':
			raw = raw[1:]
		}
	}

	iter, err := lexer.Tokenise(nil, raw)
	if err != nil {
		return ""
	}

	var sb strings.Builder

	// Write the diff prefix character without syntax coloring
	if len(content) > 0 {
		sb.WriteByte(content[0])
	}

	for _, token := range iter.Tokens() {
		entry := h.style.Get(token.Type)
		fg := entry.Colour

		if !fg.IsSet() {
			sb.WriteString(token.Value)

			continue
		}

		r, g, b := fg.Red(), fg.Green(), fg.Blue()
		sb.WriteString(fmt.Sprintf("\033[38;2;%d;%d;%dm%s\033[39m", r, g, b, token.Value))
	}

	return sb.String()
}

// styleLine combines a cached syntax-highlighted foreground with a diff
// background color. Falls back to plain diff styling when highlight is empty.
func (h *highlighter) styleLine(
	line diff.Line,
	highlight string,
	plainFallback string,
) string {
	if highlight == "" {
		return plainFallback
	}

	switch line.Type {
	case diff.Added:
		return addedBgANSI + highlight + resetANSI
	case diff.Removed:
		return removedBgANSI + highlight + resetANSI
	case diff.Context:
		return highlight
	}

	return highlight
}
