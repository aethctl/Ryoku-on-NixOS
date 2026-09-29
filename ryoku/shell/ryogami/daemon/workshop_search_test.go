package main

import (
	"strings"
	"testing"
)

func TestExtractWorkshopIDs(t *testing.T) {
	html := `
		<a class="item" href="https://steamcommunity.com/sharedfiles/filedetails/?id=123456789">A</a>
		<a href="/sharedfiles/filedetails/?id=987654321&searchtext=x">B</a>
		<div data-href="steamcommunity.com/sharedfiles/filedetails/?id=123456789">dup</div>
		<a href="/sharedfiles/filedetails/?id=0">skip zero</a>
	`
	ids := extractWorkshopIDs(html)
	want := []string{"123456789", "987654321"}
	if len(ids) != len(want) {
		t.Fatalf("ids=%v want %v", ids, want)
	}
	for i := range want {
		if ids[i] != want[i] {
			t.Fatalf("ids[%d]=%q want %q (all: %v)", i, ids[i], want[i], ids)
		}
	}
}

func TestParsePublishedFileDetails(t *testing.T) {
	// Shape captured live from GetPublishedFileDetails.
	body := []byte(`{"response":{"result":1,"resultcount":1,"publishedfiledetails":[
		{"publishedfileid":"3808523371","result":1,"title":"Neon City",
		 "file_size":"52428800","preview_url":"https://images.steamusercontent.com/x.jpg",
		 "tags":[{"tag":"Video"},{"tag":"Wallpaper"},{"tag":"3840 x 2160"}]}]}}`)
	results, err := parsePublishedFileDetails(body)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("results=%d", len(results))
	}
	r := results[0]
	if r.id != "3808523371" || r.title != "Neon City" {
		t.Fatalf("id/title: %q %q", r.id, r.title)
	}
	if r.fileSize != 52428800 {
		t.Fatalf("fileSize=%d", r.fileSize)
	}
	if r.previewURL == "" || len(r.tags) != 3 {
		t.Fatalf("preview/tags: %q %v", r.previewURL, r.tags)
	}
}

func TestParseQueryFilesPagination(t *testing.T) {
	body := []byte(`{"response":{"total":50,"publishedfiledetails":[
		{"publishedfileid":"1","title":"A","preview_url":"u","file_size":"0","tags":[{"tag":"Scene"}]},
		{"publishedfileid":"0"}]}}`)
	page, err := parseQueryFiles(body, 2, 24)
	if err != nil {
		t.Fatal(err)
	}
	if page.currentPage != 2 {
		t.Fatalf("currentPage=%d", page.currentPage)
	}
	if page.lastPage != 3 { // ceil(50/24)
		t.Fatalf("lastPage=%d want 3", page.lastPage)
	}
	if len(page.results) != 1 {
		t.Fatalf("results=%d want 1", len(page.results))
	}
}

func TestAcceptWorkshopTags(t *testing.T) {
	cases := []struct {
		tags      []string
		allowNsfw bool
		want      bool
	}{
		{[]string{"Scene"}, false, true},
		{[]string{"Video", "Wallpaper"}, false, true},
		{[]string{"Web"}, false, false},
		{[]string{"Scene", "Application"}, false, false},
		{[]string{"Game"}, false, false},
		{[]string{"Scene", "Mature"}, false, false},
		{[]string{"Scene", "Mature"}, true, true},
	}
	for _, tc := range cases {
		if got := acceptWorkshopTags(tc.tags, tc.allowNsfw); got != tc.want {
			t.Fatalf("acceptWorkshopTags(%v, nsfw=%v)=%v want %v", tc.tags, tc.allowNsfw, got, tc.want)
		}
	}
}

func TestParseHelperSearch(t *testing.T) {
	body := []byte(`{"results":[
		{"id":"42","title":"Rain","preview_url":"p","file_size":10,"subscriptions":7,"tags":"Scene, Wallpaper"}]}`)
	page, err := parseHelperSearch(body, 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(page.results) != 1 || page.results[0].id != "42" {
		t.Fatalf("results=%v", page.results)
	}
	if page.lastPage != 2 {
		t.Fatalf("lastPage=%d", page.lastPage)
	}

	if _, err := parseHelperSearch([]byte(`{"error":"Steam is not running"}`), 1); err == nil {
		t.Fatal("helper error should surface")
	}
}

func TestCommunityBrowseURL(t *testing.T) {
	u := communityBrowseURL(steamSearchParams{query: "space", queryType: 3, days: 7, tags: []string{"Scene"}, page: 2})
	for _, want := range []string{"appid=" + workshopAppID, "browsesort=trend", "searchtext=space", "p=2", "requiredtags%5B%5D=Scene", "days=7"} {
		if !strings.Contains(u, want) {
			t.Fatalf("url %q missing %q", u, want)
		}
	}
}
