---- MODULE skeenAlgorithm ----
EXTENDS TLC, Naturals, FiniteSets

CONSTANTS PROCESS_NUMBER

VARIABLES stamped, received, LC, deliverable, pc, sentM, sentTS

vars  == << stamped, received, LC, deliverable, pc, sentM, sentTS >>

(*
    PC STATES:

    BCAST = p send m to destinations
    WAITING = p waiting

*)

ASSUME PROCESS_NUMBER \in Nat

Processes == 1 .. PROCESS_NUMBER
Message == {"MESSAGE"}

Max(S) == CHOOSE t \in S : \A s \in S : t[3] >= s[3]

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
    /\ sentM' = sentM \cup {<<self, "MESSAGE">>}
    /\ pc' = [pc EXCEPT  ![self] = "PENDING"]
    /\ UNCHANGED << stamped, deliverable, sentTS, LC, received >>

    
ReceivedMessage(self) ==
    /\ sentM # {}
    /\ \E msg \in sentM: 
        /\ received' = [received EXCEPT ![self] = received[self] \cup {<<msg[1], LC[self]>>}]
        /\ sentTS' = sentTS \cup {<<self, "MESSAGE", LC[self], msg[1]>>}
    \* /\ LC' = [LC EXCEPT  ![self] = LC[self] + 1]
    /\ UNCHANGED << stamped, pc, deliverable, sentM, LC >>

ReceivedStamppedMessage(self) ==
    /\ pc[self] = "PENDING" /\ PROCESS_NUMBER = Cardinality({x \in sentTS: x[4] = self})
    /\ Print(Max({x \in sentTS: x[4] = self}), TRUE)
    /\ UNCHANGED << stamped, sentM, sentTS, pc, LC, deliverable, received >>

Step(self) ==
    \/ UpponBCAST(self)
    \/ ReceivedMessage(self)
    \/ ReceivedStamppedMessage(self)
    \/ UNCHANGED << stamped, received, pc, sentM, sentTS, LC, deliverable >>

Next == (\E p \in Processes: Step(p))

Spec == Init /\ [][Next]_vars

====