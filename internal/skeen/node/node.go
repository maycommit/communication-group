package node

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"os"
	"strings"

	"github.com/google/uuid"
	"github.com/maycommit/communication-group/protos"
	"google.golang.org/grpc"
)

type Node struct {
	protos.SkeenServer
	ID               uuid.UUID
	Host             string
	Group            map[uuid.UUID]string
	LogicalClock     int64
	ReceivedMessages []StamppedMessage
	StamppedMessages []StamppedMessage
}

func New() (*Node, error) {
	node := &Node{
		ID:    uuid.New(),
		Host:  os.Getenv("HOST"),
		Group: map[uuid.UUID]string{},
	}

	if os.Getenv("MASTER") != "" {
		err := node.Join()
		if err != nil {
			return &Node{}, err
		}
	} else {
		node.Group[node.ID] = node.Host
	}

	return node, nil
}

func (node *Node) Join() error {
	conn, err := node.NewGrpcClient(os.Getenv("MASTER"))
	if err != nil {
		return err
	}

	req := &protos.JoinNodeRequest{
		Member: &protos.Member{
			Id:   node.ID.String(),
			Host: os.Getenv("HOST"),
		},
	}

	resp, err := conn.JoinNode(context.Background(), req)
	if err != nil {
		return err
	}

	for _, m := range resp.Members {
		uuid, err := uuid.Parse(m.Id)
		if err != nil {
			return err
		}

		node.Group[uuid] = m.Host
	}

	return nil
}

func (node Node) Start() error {
	lis, err := net.Listen("tcp", node.Host)
	if err != nil {
		return err
	}

	grpcServer := grpc.NewServer()

	protos.RegisterSkeenServer(grpcServer, &node)

	fmt.Printf("Start node on %s...\n", os.Getenv("HOST"))
	go grpcServer.Serve(lis)

	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Println("\n==== COMMANDS ====")
		fmt.Printf("b: BROADCAST\nq: QUIT\n")
		command, _ := reader.ReadString('\n')
		command = strings.Replace(command, "\n", "", -1)
		switch command {
		case "b":
			fmt.Println("BROADCAST")
		case "q":
			os.Exit(0)
		}
	}
}
