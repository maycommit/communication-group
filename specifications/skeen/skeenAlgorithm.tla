---- MODULE skeenAlgorithm ----
EXTENDS TLC, Naturals, FiniteSets, Sequences

CONSTANTS NPROCESS

VARIABLES pc, sentTS, sentSN, sentM, pendingBuffer, deliveryBuffer, LC, messages

vars == << pendingBuffer, deliveryBuffer, pc, sentM, sentTS, sentSN, messages, LC >>

vars1 == << pendingBuffer, deliveryBuffer, pc, sentM, sentTS, sentSN, messages >>

Processes == 1 .. NPROCESS

Init ==
    /\ messages = {"M1", "M2", "M3"}
    /\ pendingBuffer = [i \in Processes |-> {}]
    /\ deliveryBuffer = [i \in Processes |-> {}]
    /\ pc \in [Processes -> {"BCAST", ""}]
    /\ LC = [i \in  Processes |-> 0]
    /\ sentM = {}
    /\ sentTS = {}
    /\ sentSN = {}

UpponBCAST(self) ==
    /\ pc[self] = "BCAST"
    /\ LET m == CHOOSE m \in messages: TRUE
        IN  /\ sentM' = sentM \cup { <<self, m>> }
            /\ messages' = messages \ { m }
    /\ pc' = [pc EXCEPT ![self] = "PENDING"]
    /\ UNCHANGED << LC, sentTS, sentSN, deliveryBuffer, pendingBuffer >>

ReceivedM(self) ==
    /\ \E msg \in sentM:
        /\ msg \notin pendingBuffer[self]
        /\ pendingBuffer' = [pendingBuffer EXCEPT ![self] = pendingBuffer[self] \cup { msg }]
        /\ LC' = [LC EXCEPT ![self] = LC[self] + 1]
        \* <<source, destination, message, timestamp>>
        /\ sentTS' = sentTS \cup {<<self, msg[1], msg[2], LC[self]>>}
        /\ UNCHANGED <<pc, sentSN, messages, deliveryBuffer, sentM>>

Max(S) == CHOOSE t \in S : \A s \in S : s[4] <= t[4]

ReceivedTS(self) ==
    /\ pc[self] = "PENDING"
    /\ LET msgs == { m \in sentTS: m[2] = self }
        IN  /\ NPROCESS = Cardinality(msgs)
            /\ LET m == CHOOSE m \in msgs: TRUE
                IN /\ sentSN' = sentSN \cup {<<self, m[3], Max(msgs)[4]>>}
            /\ sentM' = sentM \ { <<m[2], m[3]>> : m \in sentTS }
            /\ Print("RECEIVE ALL", TRUE)
            /\ pc' = [pc EXCEPT ![self] = "SN"]
    /\ UNCHANGED <<LC, deliveryBuffer, pendingBuffer, messages, sentTS>>

ReceivedSNMessage(self) ==
    /\ \E msg \in sentSN:
        /\ msg \notin deliveryBuffer[self]
        /\ pendingBuffer' = [pendingBuffer EXCEPT ![self] = pendingBuffer[self] \ {<<msg[1], msg[2]>>}]
        /\ deliveryBuffer' = [deliveryBuffer EXCEPT ![self] = deliveryBuffer[self] \cup {msg}]
        /\ UNCHANGED <<LC, pc, sentM, sentTS, sentSN, messages>>


Step(self) ==
    \/ UpponBCAST(self)
    \/ ReceivedM(self)
    \/ ReceivedTS(self)
    \/ ReceivedSNMessage(self)
    \/ UNCHANGED vars


Next == (\E self \in Processes: Step(self))

Fairness == WF_vars1(\E self \in Processes: Step(self))

Spec == Init /\ [][Next]_vars /\ Fairness

====