---- MODULE skeenAlgorithm ----
EXTENDS TLC, Naturals

CONSTANTS PROCESS_NUMBER

VARIABLES stamped, received, LC, deliverable, pc, sentM, sentTS

vars  == << stamped, received, LC, deliverable, pc, sentM, sentTS >>

(*
    PC STATES:

    BCAST = p send m to destinations
    WAITING = p waiting 
*)

Processes == 1 .. PROCESS_NUMBER
Message == {"SKEENS"}

Init ==
  /\ stamped = [ i \in Processes |-> {}]
  /\ received = [i \in Processes |-> {}]
  /\ deliverable = [i \in Processes |-> {}]
  /\ pc \in [Processes -> {"BCAST", "MEMBER"}]
  /\ LC \in [Processes -> {0}]
  /\ sentM = {}
  /\ sentTS = {}

Broadcast(self) ==
  /\ pc[self] = "BCAST"
  /\ pc' = [pc EXCEPT  ![self] = "WAITING"]
  /\ sentM' = sentM \cup {<<self, "SKEENS">>}
  /\ UNCHANGED << stamped, received, LC, sentTS, deliverable >>

ReceivedMessage(self) ==
    /\ \E msg \in sentM:
        /\ msg \notin received[self]
        /\ received' = [received EXCEPT ![self] = received[self] \cup {msg}]
        /\ sentTS' = sentTS \cup {<<self, "SKEENS", LC[self]>>}
        /\ LC' = [LC EXCEPT  ![self] = LC[self] + 1]
        /\ UNCHANGED << stamped, received, sentM, pc, deliverable >>

ReceivesMessageAndTimestamp(self) ==
    /\ pc[self] = "WAITING"
    /\ \E msg \in sentTS:
        /\

Step(self) ==
  \/ Broadcast(self)
  \/ ReceivedMessage(self)
  \/ UNCHANGED << stamped, received, pc, LC, sentM, sentTS, deliverable >>

Next == (\E p \in Processes: Step(p))

Spec == Init /\ [][Next]_vars
             /\ WF_vars(\E p \in Processes: /\ ReceivedMessage(p)
                                            /\ \/ Broadcast(p)
                                               \/ UNCHANGED << stamped, received, pc, LC, sentM, sentTS, deliverable >>)

====