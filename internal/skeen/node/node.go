package node

import (
	"context"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/maycommit/communication-group/protos"
	"google.golang.org/grpc"
)

type Node struct {
	protos.SkeenServer
	ID    uuid.UUID
	Group map[uuid.UUID]string
}

func New() (Node, error) {
	node := Node{
		ID:    uuid.New(),
		Group: map[uuid.UUID]string{},
	}

	if os.Getenv("MASTER") != "" {
		err := node.Join()
		if err != nil {
			return Node{}, err
		}
	} else {
		node.Group[node.ID] = os.Getenv("HOST")
	}

	return node, nil
}

func (node Node) NewGrpcClient(address string) (protos.SkeenClient, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	conn, err := grpc.DialContext(ctx, address)
	if err != nil {
		return nil, err
	}

	return protos.NewSkeenClient(conn), nil
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
	lis, err := net.Listen("tcp", os.Getenv("HOST"))
	if err != nil {
		return err
	}

	grpcServer := grpc.NewServer()

	protos.RegisterSkeenServer(grpcServer, node)

	fmt.Printf("Start node on %s...\n", os.Getenv("HOST"))
	return grpcServer.Serve(lis)
}
