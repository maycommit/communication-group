---- MODULE skeenAlgorithm ----
EXTENDS TLC, Naturals, FiniteSets, Sequences

CONSTANTS PROCESS_NUMBER, MAX_LC

VARIABLES pendingBuffer, deliveryBuffer, LC, pc, sent, sn, received

vars  == << pendingBuffer, deliveryBuffer, LC, pc, sent, sn, received >>

(*
    PC STATES:

    BCAST = TO-broadcast
    PENDING = Wait all local timestamps
    SN = Send sequence number to detinations
    AC = TO-deliver
*)

ASSUME PROCESS_NUMBER \in Nat /\ MAX_LC \in Nat

Processes == 1 .. PROCESS_NUMBER
Message == {"MESSAGE"}

Init ==
  /\ pendingBuffer = [i \in Processes |-> {}]
  /\ deliveryBuffer = [i \in Processes |-> {}]
  /\ received = [i \in Processes |-> {}]
  /\ pc \in [Processes -> {"BCAST", ""}]
  /\ LC \in [Processes -> 1 .. MAX_LC]
  /\ sent = {}
  /\ sn = 0

Max(S) == CHOOSE t \in S : \A s \in S : t[5] >= s[5]

\* Pool de msgs
\* LC de verdade

UpponBCAST(self) ==
    /\ pc[self] = "BCAST"
    /\ pc' = [pc EXCEPT  ![self] = "PENDING"]
    /\ sent' = sent \cup { <<self, "BCAST", "MESSAGE">> } (* << SOURCE, TYPE, MESSAGE >> *)
    /\ UNCHANGED << LC, deliveryBuffer, pendingBuffer, sn, received >>
    
UpponBCASTMessage(self) ==
    /\ \E msg \in {m \in sent: m[2] = "BCAST"}:
        /\ pendingBuffer' = [pendingBuffer EXCEPT ![self] = pendingBuffer[self] \cup { msg }]
        /\ sent' = sent \cup {<<self, "TS", "MESSAGE", msg[1], LC[self]>>}
        /\ UNCHANGED <<LC, deliveryBuffer, received, pc, sn>>

UpponAllTSMessage(self) ==
    /\ pc[self] = "PENDING"
    /\ LET msgs == {m \in sent: m[2] = "TS" /\ m[4] = self}
        IN  /\ PROCESS_NUMBER = Cardinality(msgs)
            /\ sent' = sent \cup {<<self, "SN", "MESSAGE", Max(msgs)[5]>>}
            /\ pc' = [pc EXCEPT ![self] = "SN"]
            /\ UNCHANGED <<LC, deliveryBuffer, received, pendingBuffer, sn>>

UpponSNMessage(self) ==
    /\ LET msgs == {m \in sent: m[2] = "SN"}
        IN  /\ pendingBuffer' = [pendingBuffer EXCEPT ![self] = {<<i, "BCAST", "MESSAGE">> : i \in Processes} \ pendingBuffer[self]]
            /\ deliveryBuffer' = [deliveryBuffer EXCEPT ![self] = msgs]
            /\ UNCHANGED <<LC, pc, received, sent, sn>>

Deliver(self) ==
    /\ TRUE

Step(self) ==
    /\ Deliver(self)
    /\  \/ UpponBCAST(self)
        \/ UpponBCASTMessage(self)
        \/ UpponAllTSMessage(self)
        \/ UpponSNMessage(self)
        \/ UNCHANGED <<LC, deliveryBuffer, pendingBuffer, pc, received, sent, sn>>


Next == (\E self \in Processes: Step(self))

Spec == Init /\ [][Next]_vars
             /\ WF_vars(\E self \in Processes: Step(self))

(*  ---- PROPERTIES ---- *)

(* AGREEMENT *)

(* VALIDITY *)

(* INTEGRITY *)

(* TOTAL ORDER *)

====