package digest

import "testing"

func TestSHA256IsDomainSeparated(t *testing.T) {
	a := SHA256("baseline", []byte("same"))
	b := SHA256("revision", []byte("same"))
	if a == b {
		t.Fatal("domain separation did not change digest")
	}
	if !Valid(a) {
		t.Fatalf("invalid digest %q", a)
	}
}

func TestRevisionID(t *testing.T) {
	got := RevisionID([]byte(`{}`))
	if !ValidRevisionID(got) {
		t.Fatalf("invalid revision ID %q", got)
	}
	if got != "ffr1:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a" {
		t.Fatalf("unexpected revision ID %q", got)
	}
}
