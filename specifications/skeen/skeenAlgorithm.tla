---- MODULE skeenAlgorithm ----
EXTENDS TLC, Naturals, FiniteSets, Sequences

CONSTANTS PROCESS_NUMBER, MAX_LC

VARIABLES pendingBuffer, deliveryBuffer, LC, pc, sent, received, messages

vars  == << pendingBuffer, deliveryBuffer, LC, pc, sent, received, messages >>

(*
    PC STATES:

    BCAST = TO-broadcast
    PENDING = Wait all local timestamps
    SN = Send sequence number to detinations
    AC = TO-deliver
*)

ASSUME PROCESS_NUMBER \in Nat /\ MAX_LC \in Nat

Processes == 1 .. PROCESS_NUMBER
Messages == {"MESSAGE1"}

Init ==
  /\ pendingBuffer = [i \in Processes |-> {}]
  /\ deliveryBuffer = [i \in Processes |-> {}]
  /\ received = [i \in Processes |-> {}]
  /\ messages = [i \in Processes |-> Messages]
  /\ pc \in [Processes -> {"BCAST", ""}]
  /\ LC \in [Processes -> 1 .. MAX_LC]
  /\ sent = {}

Max(S) == CHOOSE t \in S : \A s \in S : t[5] >= s[5]

\* LC de verdade
UpponBCAST(self) ==
    /\ (pc[self] = "BCAST") /\ (messages[self] # {})
    /\ LET msg == CHOOSE msg \in messages[self] : TRUE
        IN  /\ sent' = sent \cup {<<self, "BCAST", msg>>}
            /\ messages' = [messages EXCEPT ![self] = messages[self] \ {msg}]
            /\ UNCHANGED << LC, deliveryBuffer, pendingBuffer, pc >>

UpponSendAllMenssages(self) ==
    /\ (pc[self] = "BCAST") /\ (messages[self] = {})
    /\ pc' = [pc EXCEPT  ![self] = "PENDING"]
    /\ UNCHANGED <<LC, deliveryBuffer, pendingBuffer, messages, sent>>
    
UpponBCASTMessage(self) ==
    /\ \E msg \in {m \in sent: m[2] = "BCAST"}:
        /\ pendingBuffer' = [pendingBuffer EXCEPT ![self] = pendingBuffer[self] \cup { msg }]
        /\ sent' = sent \cup {<<self, "TS", msg[2], msg[1], LC[self]>>}
        /\ UNCHANGED <<LC, deliveryBuffer, pc, messages>>

UpponAllTSMessage(self) ==
    /\ pc[self] = "PENDING"
    /\ LET msgs == {m \in sent: m[2] = "TS" /\ m[4] = self}
        IN  /\ PROCESS_NUMBER = Cardinality(msgs)
            /\ sent' = sent \cup {<<self, "SN", "MESSAGE", Max(msgs)[5]>>}
            /\ pc' = [pc EXCEPT ![self] = "SN"]
            /\ UNCHANGED <<LC, deliveryBuffer, pendingBuffer, messages>>


\* Verificar inconsistencia aqui
UpponSNMessage(self) ==
    /\ LET msgs == {m \in sent: m[2] = "SN"}
        IN  /\ pendingBuffer' = [pendingBuffer EXCEPT ![self] = {<<i, "BCAST", "tftft">> : i \in Processes} \ pendingBuffer[self]]
            /\ deliveryBuffer' = [deliveryBuffer EXCEPT ![self] = msgs]
            /\ UNCHANGED <<LC, pc, sent, messages>>

\* tudo do delivery buffer é entregavel

Deliver(self) ==
    /\ received' = [received EXCEPT ![self] = pendingBuffer[self]]



Step(self) ==
    /\ Deliver(self)
    /\  \/ UpponBCAST(self)
        \/ UpponSendAllMenssages(self)
        \/ UpponBCASTMessage(self)
        \/ UpponAllTSMessage(self)
        \/ UpponSNMessage(self)
        \/ UNCHANGED <<LC, deliveryBuffer, pendingBuffer, pc, sent, messages>>


Next == (\E self \in Processes: Step(self))

Spec == Init /\ [][Next]_vars
             /\ WF_vars(\E self \in Processes: Step(self))

(*  ---- PROPERTIES ---- *)

(* AGREEMENT *)

(* VALIDITY *)

(* INTEGRITY *)

(* TOTAL ORDER *)

====