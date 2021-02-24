package node

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"os"
	"strings"
	"text/tabwriter"
	"time"

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
	Deliverable      []StamppedMessage
	ReceivedBuffer   map[string][]StamppedMessage
}

func New() (*Node, error) {
	node := &Node{
		ID:   uuid.New(),
		Host: os.Getenv("HOST"),
		Group: map[uuid.UUID]string{
			uuid.MustParse("531924fb-6fb6-44fe-85d6-d64a3913f599"): ":8000",
			uuid.MustParse("d59d6f7f-efe3-4643-afcc-bde412508511"): ":8001",
			uuid.MustParse("5f8007f7-04ef-4163-b75e-2f3279220175"): ":8002",
		},
		ReceivedBuffer: map[string][]StamppedMessage{},
		LogicalClock:   0,
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

func (node Node) sendMessageToDestinations() error {
	newMessage := &protos.SendMessageRequest{
		Id:      uuid.NewString(),
		Message: "MESSAGE - " + time.Now().String(),
		Owner:   node.Host,
	}

	return node.Broadcast(func(conn protos.SkeenClient) error {
		_, err := conn.SendMessage(context.TODO(), newMessage)
		return err
	})
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
		fmt.Println("b: BROADCAST")
		fmt.Println("g: GROUP")
		fmt.Println("r: RECEIVED MESSAGES")
		fmt.Println("s: STAMPPED MESSAGES")
		fmt.Println("f: RECEIVED BUFFER")
		fmt.Println("q: QUIT")

		command, _ := reader.ReadString('\n')
		command = strings.Replace(command, "\n", "", -1)
		switch command {
		case "b":
			fmt.Println("SEND MESSAGE TO DESTINATIONS...")
			err := node.sendMessageToDestinations()
			if err != nil {
				panic(err)
			}
		case "g":
			node.printGroup()
		case "r":
			node.printReceivedMessages()
		case "s":
			node.printStamppedMessages()
		case "f":
			node.printReceivedBuffer()
		case "d":
			node.printDeliverableMessages()
		case "q":
			os.Exit(0)
		}
	}
}

func (node Node) printReceivedMessages() {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintf(w, "ID\tMESSAGE\tTIMESTAMP\tOWNER\n")
	for _, m := range node.ReceivedMessages {
		fmt.Fprintf(w, "%s\t%s\t%d\t%s\n", m.ID, m.Message, m.Timestamp, m.Owner)
	}
	w.Flush()
}

func (node Node) printStamppedMessages() {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintf(w, "ID\tMESSAGE\tTIMESTAMP\tOWNER\n")
	for _, m := range node.StamppedMessages {
		_, _ = fmt.Fprintf(w, "%s\t%s\t%d\t%s\n", m.ID, m.Message, m.Timestamp, m.Owner)
	}
	_ = w.Flush()
}

func (node Node) printDeliverableMessages() {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintf(w, "ID\tMESSAGE\tTIMESTAMP\tOWNER\n")
	for _, m := range node.Deliverable {
		_, _ = fmt.Fprintf(w, "%s\t%s\t%d\t%s\n", m.ID, m.Message, m.Timestamp, m.Owner)
	}
	_ = w.Flush()
}

func (node Node) printReceivedBuffer() {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	_, _ = fmt.Fprintf(w, "MESSAGEID\n")
	for id, ms := range node.ReceivedBuffer {
		fmt.Fprintf(w, "%s\n", id)

		fmt.Fprintf(w, "ID\tMESSAGE\tTIMESTAMP\tOWNER\n")
		for _, m := range ms {
			fmt.Fprintf(w, "%s\t%s\t%d\t%s\n", m.ID, m.Message, m.Timestamp, m.Owner)
		}
	}
	_ = w.Flush()
}

func (node Node) printGroup() {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	_, _ = fmt.Fprintf(w, "ID\tHOST\n")
	for id, host := range node.Group {
		_, _ = fmt.Fprintf(w, "%s\t%s\n", id.String(), host)
	}
	_ = w.Flush()
}
