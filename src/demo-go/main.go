package main

import (
	"fmt"
	"net/http"
	"os"

	"golang.org/x/sys/unix"
)

// GET /attack/fileless-rce
//
// Demonstrates the "fileless" primitive used by real in-memory malware:
// memfd_create(2) makes an anonymous file that lives only in RAM and never
// touches the disk. A real attacker would then write an ELF into it and run
// it via /proc/self/fd/N, bypassing a read-only filesystem entirely.
//
// This handler is BENIGN on purpose: it only creates the in-memory fd and
// reports whether the syscall is permitted. It does NOT write or execute any
// attacker-supplied code. The security point is simply that the primitive is
// AVAILABLE on a normal container -- and that Seccomp can take it away.
//
//   - Vulnerable container: memfd_create succeeds  -> primitive available (RED)
//   - Seccomp-hardened:     memfd_create -> EPERM   -> blocked at the kernel (GREEN)
func filelessHandler(w http.ResponseWriter, r *http.Request) {
	fd, err := unix.MemfdCreate("demo-in-ram", unix.MFD_CLOEXEC)
	if err != nil {
		// The kernel (via Seccomp) refused the syscall.
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "[BLOCKED] memfd_create denied: %v\n", err)
		return
	}
	defer unix.Close(fd)

	// Prove it is a real, writable, in-memory file with no path on disk.
	if _, err := unix.Write(fd, []byte("hello from RAM\n")); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "[BLOCKED] write to in-memory fd denied: %v\n", err)
		return
	}

	memPath := fmt.Sprintf("/proc/self/fd/%d", fd)
	// A real attacker would now exec(memPath) to run an in-memory ELF.
	// We STOP here deliberately: the point is that the primitive exists.
	fmt.Fprintf(w,
		"[SUCCEEDED] fileless primitive available: in-RAM fd %d at %s (no file on disk).\n"+
			"A real attacker would now write an ELF here and exec it. Seccomp removes this syscall.\n",
		fd, memPath)
}

func main() {
	http.HandleFunc("/attack/fileless-rce", filelessHandler)
	fmt.Println("Go fileless demo listening on port 8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		os.Exit(1)
	}
}
