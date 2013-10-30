Require Import Coq.ZArith.ZArith.

Require Import ByteData.
Require Import File.
Require Import FileSystems.
Require Import Util.

Open Local Scope Z.

Inductive Event: Type :=
  | FileAccess: Z -> Z -> Event
  | FileModification: Z -> Z -> Event
  | FileCreation: Z -> Z -> Event
  | FileDeletion: Z -> Z -> Event
.

Definition Timeline: Type := list Event.

Definition timestampOf (event: Event) : Exc Z :=
  match event with
  | FileAccess timestamp _ => value timestamp
  | FileModification timestamp _ => value timestamp
  | FileCreation timestamp _ => value timestamp
  | FileDeletion timestamp _ => value timestamp
  end.

Definition beforeOrConcurrent (lhs rhs: Event) :=
  match (timestampOf lhs, timestampOf rhs) with
  | (value lhs_time, value rhs_time) => lhs_time <= rhs_time
  | _ => False
  end.

Definition foundOn (event: Event) (disk: Disk) : Prop :=
  exists (file: File),
    isOnDisk file disk
    /\ (match event with
        | FileAccess timestamp fsId =>
            file.(fileSystemId) = value fsId
            /\ file.(lastAccess) = value timestamp
       | FileModification timestamp fsId =>
            file.(fileSystemId) = value fsId
            /\ file.(lastModification) = value timestamp
       | FileCreation timestamp fsId =>
            file.(fileSystemId) = value fsId
            /\ file.(lastCreated) = value timestamp
       | FileDeletion timestamp fsId =>
            file.(fileSystemId) = value fsId
            /\ file.(lastDeleted) = value timestamp
       end).

Definition isInOrder (timeline: Timeline) :=
  (* Events are in the correct sequence *)
  (forall (index: nat),
    (index < ((length timeline) - 1) )%nat ->
      match (nth_error timeline index, 
             nth_error timeline (index + 1)) with
      | (value lhsEvent, value rhsEvent) => 
        beforeOrConcurrent lhsEvent rhsEvent
      | _ => False
      end).

Definition isSound (timeline: Timeline) (disk: Disk) :=
  (forall (event: Event),
    (* Event is evident from the disk *)
    (In event timeline) -> (foundOn event disk))
  /\ isInOrder timeline.