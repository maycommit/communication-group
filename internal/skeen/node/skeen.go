package node

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/maycommit/communication-group/protos"
	"github.com/thoas/go-funk"
)

type StamppedMessage struct {
	ID        string
	Message   string
	Owner     string
	Timestamp int64
}

func (node *Node) JoinNode(ctx context.Context, request *protos.JoinNodeRequest) (*protos.JoinNodeResponse, error) {
	if request == nil {
		return nil, errors.New("Invalid member")
	}

	member := request.Member

	uuid, err := uuid.Parse(member.Id)
	if err != nil {
		return nil, err
	}

	node.Group[uuid] = member.Host

	response := protos.JoinNodeResponse{Members: []*protos.Member{}}

	for uuid, host := range node.Group {
		response.Members = append(response.Members, &protos.Member{
			Id:   uuid.String(),
			Host: host,
		})
	}

	return &response, nil
}

func (node *Node) SendMessage(ctx context.Context, request *protos.SendMessageRequest) (*protos.Any, error) {
	timestamp := node.LogicalClock

	node.ReceivedMessages = append(node.ReceivedMessages, StamppedMessage{
		ID:        request.Id,
		Message:   request.Message,
		Timestamp: timestamp,
		Owner:     request.Owner,
	})

	err := node.Broadcast(func(conn protos.SkeenClient) error {
		_, err := conn.SendStamppedMessage(context.Background(), &protos.SendStamppedMessageRequest{
			Id:        request.Id,
			Owner:     node.Host,
			Message:   request.Message,
			Timestamp: timestamp,
		})

		if err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		return &protos.Any{}, err
	}

	node.LogicalClock += 1
	return &protos.Any{}, nil
}

func (node *Node) SendStamppedMessage(ctx context.Context, request *protos.SendStamppedMessageRequest) (*protos.Any, error) {
	node.LogicalClock = funk.MaxInt64([]int64{request.Timestamp, node.LogicalClock + 1}).(int64)
	node.ReceivedBuffer[request.Id] = append(node.ReceivedBuffer[request.Id], StamppedMessage{
		ID:        request.Id,
		Message:   request.Message,
		Timestamp: request.Timestamp,
		Owner:     request.Owner,
	})

	if len(node.ReceivedBuffer[request.Id]) == len(node.Group) {
		allTimestamps := funk.Map(node.ReceivedBuffer[request.Id], func(st StamppedMessage) int64 {
			return st.Timestamp
		}).([]int64)
		sn := funk.MaxInt64(allTimestamps).(int64)

		node.StamppedMessages = append(node.StamppedMessages, StamppedMessage{
			ID:        request.Id,
			Message:   request.Message,
			Timestamp: sn,
		})

		node.ReceivedMessages = funk.Filter(node.ReceivedMessages, func(s StamppedMessage) bool {
			return s.ID != request.Id
		}).([]StamppedMessage)

		node.Deliverable = []StamppedMessage{}
		for _, mi := range node.StamppedMessages {
			for _, mj := range node.ReceivedMessages {
				if mi.Timestamp < mj.Timestamp {
					node.Deliverable = append(node.Deliverable, StamppedMessage{
						ID:        mi.ID,
						Message:   mi.Message,
						Timestamp: mi.Timestamp,
					})
				}
			}
		}

		stamppedDiff, _ := funk.Difference(node.StamppedMessages, node.Deliverable)
		node.StamppedMessages = stamppedDiff.([]StamppedMessage)

		// node.StamppedMessages = funk.Filter(node.StamppedMessages, func(st StamppedMessage) bool {
		// 	return !funk.Contains(deliverable, st.ID)
		// }).([]StamppedMessage)

		delete(node.ReceivedBuffer, request.Id)
	}

	return &protos.Any{}, nil
}
