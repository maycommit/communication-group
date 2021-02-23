package main

import (
	"flag"
	"log"
	"os"

	"github.com/maycommit/communication-group/internal/skeen/node"
)

func init() {
	host := flag.String("host", ":8000", "Node address")
	master := flag.String("master", "", "Node master address")

	flag.Parse()

	os.Setenv("HOST", *host)
	os.Setenv("MASTER", *master)
}

func main() {
	node, err := node.New()
	if err != nil {
		panic(err)
	}

	log.Fatalln(node.Start())
}
