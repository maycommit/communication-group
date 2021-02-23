package node

import (
	"context"
	"time"

	"github.com/maycommit/communication-group/protos"
	"google.golang.org/grpc"
)

func (node Node) NewGrpcClient(address string) (protos.SkeenClient, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	opts := []grpc.DialOption{
		grpc.WithBlock(),
		grpc.WithTimeout(10 * time.Second),
		grpc.FailOnNonTempDialError(true),
		grpc.WithInsecure(),
	}

	conn, err := grpc.DialContext(ctx, address, opts...)
	if err != nil {
		return nil, err
	}

	return protos.NewSkeenClient(conn), nil
}

func (node Node) Broadcast(cb func(conn protos.SkeenClient) error) error {
	for id, host := range node.Group {
		if node.ID == id {
			continue
		}

		conn, err := node.NewGrpcClient(host)
		if err != nil {
			return err
		}

		err = cb(conn)
		if err != nil {
			return err
		}
	}

	return nil
}
