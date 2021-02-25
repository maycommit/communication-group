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
    /\ sentM' = sentM \cup {<<self, "MESSAGE">>}
    /\ pc' = [pc EXCEPT  ![self] = "PENDING"]
    /\ stamped'= stamped
    /\ deliverable'= deliverable
    /\ sentTS' = sentTS
    /\ LC' =  LC

ReceivedMessageExpression(self, i) ==
    /\ received' = [received EXCEPT ![self] = received[self] \cup {<<i[1], LC[self]>>}]
    /\ sentTS' = sentTS \cup {<<self, "MESSAGE", LC[self], i[1]>>}
    

ReceivedMessage(self) ==
    /\ \A i \in sentM: ReceivedMessageExpression(self, i)
    /\ LC' = [LC EXCEPT  ![self] = LC[self] + 1]
    /\ stamped' = stamped
    /\ pc' = pc
    /\ deliverable' = deliverable
    /\ sentM' = sentM

Step(self) ==
    /\ ReceivedMessage(self)
    /\ \/ UpponBCAST(self)
       \/ UNCHANGED << stamped, received, pc, sentM, sentTS, deliverable >>

Next == (\E p \in Processes: Step(p))

Spec == Init /\ [][Next]_vars
             /\ WF_vars(\E p \in Processes: /\ ReceivedMessage(p)
                                            /\ \/ UpponBCAST(p)
                                               \/ UNCHANGED << stamped, received, pc, LC, sentM, sentTS, deliverable >>)

====