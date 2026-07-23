package main

import (
	"encoding/json"
	"fmt"
	"os"
)

type inventory struct {
	Targets []target `json:"targets"`
}

type target struct {
	ID         string `json:"id"`
	GOOS       string `json:"goos"`
	GOARCH     string `json:"goarch"`
	Executable string `json:"executable"`
	State      string `json:"state"`
}

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: ff-integrity-target <targets.json> <target>")
		os.Exit(2)
	}
	raw, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	var values inventory
	if err := json.Unmarshal(raw, &values); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	for _, value := range values.Targets {
		if value.ID == os.Args[2] && value.State == "supported" {
			fmt.Printf("%s\t%s\t%s\n", value.GOOS, value.GOARCH, value.Executable)
			return
		}
	}
	fmt.Fprintf(os.Stderr, "target is not supported by inventory: %s\n", os.Args[2])
	os.Exit(1)
}
