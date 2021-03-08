---- MODULE skeenAlgorithm ----
EXTENDS TLC, Naturals, FiniteSets, Sequences

CONSTANTS PROCESS_NUMBER, MAX_LC

VARIABLES pendingBuffer, deliveryBuffer, LC, pc, sent, sn, received

vars  == << pendingBuffer, deliveryBuffer, LC, pc, sent, sn, received >>

(*
    PC STATES:

    BCAST = TO-broadcast
    PENDING = Wait all local timestamps
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

Max(S) == CHOOSE t \in S : \A s \in S : t[3] >= s[3]

UpponBCAST(self) ==
    /\ pc[self] = "BCAST"
    /\ pc' = [pc EXCEPT  ![self] = "PENDING"]
    /\ sent' = sent \cup { <<self, "BCAST", "MESSAGE">> } (* << SOURCE, TYPE, MESSAGE >> *)
    /\ LC' = LC
    /\ UNCHANGED << LC, deliveryBuffer, sn, received >>

ReceivedBCASTMessage(self) ==
    /\ \E msgs \in SUBSET { <<i, "BCAST", "MESSAGE">> : i \in Processes}:
        /\ msgs \subseteq sent
        /\ pendingBuffer' = [pendingBuffer EXCEPT ![self] = msgs]

UpponBCASTMessage(self) ==
    /\ pendingBuffer[self] # {}
    /\ sent' = sent \cup {<<self, "TS", "MESSAGE", m[1], LC[self]>> : m \in pendingBuffer[self]}
    /\ UNCHANGED <<LC, deliveryBuffer, received, pc, sn>>

UpponAllTSMessage(self) ==
    /\ pc[self] = "PENDING"
    /\ PROCESS_NUMBER = Cardinality({m \in sent: (Len(m) = 4) /\ (m[4] = self) /\ (m[2] = "TS")})
    /\ sn' = Max({m \in sent: (m[4] = self) /\ (m[2] = "TS")})
    /\ sent' = sent \cup {<<self, "SN", "MESSAGE", sn>>}
    /\ UNCHANGED <<LC, pc, received, deliveryBuffer, pendingBuffer>>

ReceivedSNMessage(self) ==
    /\ \E msgs \in SUBSET {<<i, "SN", "MESSAGE", sn>> : i \in Processes}:
        /\ msgs \subseteq sent
        /\ pendingBuffer'[self] = pendingBuffer[self] \ {<<i, "BCAST", "MESSAGE">> : i \in Processes}
        /\ deliveryBuffer' = [deliveryBuffer EXCEPT ![self] = msgs]

Step(self) ==
    /\ ReceivedBCASTMessage(self)
    \* /\ ReceivedSNMessage(self)
    /\  \/ UpponBCAST(self)
        \/ UpponBCASTMessage(self)
        \/ UpponAllTSMessage(self)
        \/ UNCHANGED <<LC, deliveryBuffer, pc, received, sent, sn>>


Next == (\E self \in Processes: Step(self))

Spec == Init /\ [][Next]_vars
             /\ WF_vars(\E self \in Processes: Step(self))

(*  ---- PROPERTIES ---- *)

(* AGREEMENT *)

(* VALIDITY *)

(* INTEGRITY *)

(* TOTAL ORDER *)

====