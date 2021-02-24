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
Message == {"MESSAGE"}

Init ==
  /\ stamped = [ i \in Processes |-> {}]
  /\ received = [i \in Processes |-> {}]
  /\ deliverable = [i \in Processes |-> {}]
  /\ pc \in [Processes -> {"BCAST", ""}]
  /\ LC \in [Processes -> {0}]
  /\ sentM = {}
  /\ sentTS = {}

UpponBCAST(self) ==
    /\ pc[self] = "BCAST"
    /\ pc' = [pc EXCEPT  ![self] = "PENDING"]
    /\ sentM' = sentM \cup {<<self, "MESSAGE">>}
    /\ UNCHANGED << stamped, received, LC, sentTS, deliverable >>

UpponTimestamps(self) ==
    /\ pc[self] # "BCAST"
    /\ \A i \in sentM:
        /\ received' = [received EXCEPT ![self] = received[self] \cup {<<i[1], LC[self]>>} ]
        /\ sentTS' = sentTS \cup {<<self, "MESSAGE", LC[self], i[1]>>}
        /\ LC' = [LC EXCEPT  ![self] = LC[self] + 1]

\* ReceivedMessage(self) ==
\*     /\ \E msg \in sentM:
\*         /\ msg \notin received[self]
\*         /\ received' = [received EXCEPT ![self] = received[self] \cup {msg}]
\*         /\ sentTS' = sentTS \cup {<<self, "SKEENS", LC[self]>>}
\*         /\ LC' = [LC EXCEPT  ![self] = LC[self] + 1]
\*         /\ UNCHANGED << stamped, received, sentM, pc, deliverable >>

\* ReceivesMessageAndTimestamp(self) ==
\*     /\ pc[self] = "WAITING"
\*     /\ \E msg \in sentTS: 

Step(self) ==
  \/ UpponBCAST(self)
  \/ UpponTimestamps(self)
  \/ UNCHANGED << stamped, received, pc, LC, sentM, sentTS, deliverable >>

Next == (\E p \in Processes: Step(p))

Spec == Init /\ [][Next]_vars
             /\ WF_vars(\E p \in Processes: \/ Broadcast(p)
                                            \/ UNCHANGED << stamped, received, pc, LC, sentM, sentTS, deliverable >>)

====