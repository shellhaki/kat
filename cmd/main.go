// Copyright (c) 2026 Haki. All rights reserved.
//
// This source code is proprietary and may not be copied, modified,
// distributed, or used without prior written permission from the copyright holder.

// steps are, collect args from the os, check if the args are less than 2, if so no gree
// then write a function that checks if a file is missing
// then write a function that reads the content of a file into a string
// then log the content to the terminal

package main

import (
	"fmt"
	"log"
	"os"
)

// set at build time with -ldflags "-X main.version=..."
var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	args := os.Args
	if len(args) < 2 {
		fmt.Println("invalid usage; try: kat <fileName>")
		return
	}
	filename := os.Args[1]
	if filename == "-v" || filename == "--version" {
		fmt.Printf("kat %s (commit %s, built %s)\n", version, commit, date)
		return
	}
	exists := FileExist(filename)
	if !exists {
		fmt.Println("file not found")
	} else {
		content, err := ReadFile(filename)
		if err != nil {
			log.Println(err.Error())
		} else {
			fmt.Println(content)
		}
	}
}

func FileExist(filename string) bool {
	if _, err := os.Stat(filename); os.IsNotExist(err) {
		return false
	}
	return true
}

func ReadFile(filename string) (string, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		log.Panic(err)
	}
	return string(data), nil
}
