(* positive negative examples for what doesn't work and what does; e.g. coqchk
*)


Require Import Coq.ZArith.ZArith.

Require Import ByteData.
Require Import File.
Require Import FileData.
Require Import FileIds.
Require Import Util.

Open Local Scope bool.
Open Local Scope N.

Inductive Event: Type :=
  | FileAccess: N -> FileId -> Event
  | FileModification: N -> FileId -> Event
  | FileCreation: N -> FileId -> Event
  | FileDeletion: N -> FileId -> Event
.

Definition eqb (lhs rhs: Event) :=
  match (lhs, rhs) with
  | (FileAccess l lfs, FileAccess r rfs) => 
      andb (FileIds.eqb lfs rfs) (N.eqb l r)
  | (FileModification l lfs, FileModification r rfs) => 
      andb (FileIds.eqb lfs rfs) (N.eqb l r)
  | (FileCreation l lfs, FileCreation r rfs) =>
      andb (FileIds.eqb lfs rfs) (N.eqb l r)
  | (FileDeletion l lfs, FileDeletion r rfs) =>
      andb (FileIds.eqb lfs rfs) (N.eqb l r)
  | _ => false
  end.

Definition Timeline: Type := list Event.

Definition timestampOf (event: Event) : Exc N :=
  match event with
  | FileAccess timestamp _ => value timestamp
  | FileModification timestamp _ => value timestamp
  | FileCreation timestamp _ => value timestamp
  | FileDeletion timestamp _ => value timestamp
  end.

Definition beforeOrConcurrent (lhs rhs: Event) :=
  match (timestampOf lhs, timestampOf rhs) with
  | (value lhs_time, value rhs_time) => lhs_time <=? rhs_time
  | _ => false
  end.

Definition foundOn (event: Event) (disk: Disk) :=
  exists (file: File),
    isOnDisk file disk
    /\ match event with
       | FileAccess timestamp fs =>
          fs = file.(fileId) /\ file.(lastAccess) = value timestamp
       | FileModification timestamp fs =>
          fs = file.(fileId) /\ file.(lastModification) = value timestamp
       | FileCreation timestamp fs =>
          fs = file.(fileId) /\ file.(lastCreated) = value timestamp
       | FileDeletion timestamp fs =>
          fs = file.(fileId) /\ file.(lastDeleted) = value timestamp
       end.

Definition foundOn_compute (event: Event) (disk: Disk) (file: File) :=
  isOnDisk_compute file disk
  && match event with
     | FileAccess timestamp fs =>
        FileIds.eqb fs file.(fileId)
        && optN_eqb file.(lastAccess) (value timestamp)
     | FileModification timestamp fs =>
        FileIds.eqb fs file.(fileId)
        && optN_eqb file.(lastModification) (value timestamp)
     | FileCreation timestamp fs =>
        FileIds.eqb fs file.(fileId)
        && optN_eqb file.(lastCreated) (value timestamp)
     | FileDeletion timestamp fs =>
        FileIds.eqb fs file.(fileId)
        && optN_eqb file.(lastDeleted) (value timestamp)
     end.

Lemma foundOn_reflection (event: Event) (disk: Disk) (file: File) :
  foundOn_compute event disk file = true -> foundOn event disk.
Proof.
  intros. unfold foundOn_compute in H. 
  apply Bool.andb_true_iff in H. destruct H.
  unfold foundOn. exists file.
  split. apply isOnDisk_reflection. auto.
  destruct event.
    apply Bool.andb_true_iff in H0. destruct H0. 
      split. apply FileIds.eqb_reflection. auto.
             apply optN_eqb_reflection. auto.
    apply Bool.andb_true_iff in H0. destruct H0. 
      split. apply FileIds.eqb_reflection. auto.
             apply optN_eqb_reflection. auto.
    apply Bool.andb_true_iff in H0. destruct H0. 
      split. apply FileIds.eqb_reflection. auto.
             apply optN_eqb_reflection. auto.
    apply Bool.andb_true_iff in H0. destruct H0. 
      split. apply FileIds.eqb_reflection. auto.
             apply optN_eqb_reflection. auto.
Qed. 

Definition isSoundPair (disk: Disk) (pair: ((Event*File)*(Event*File))) :=
  match pair with
  | ((lhsEvent, lhsFile), (rhsEvent, rhsFile)) =>
      foundOn_compute lhsEvent disk lhsFile
      && foundOn_compute rhsEvent disk rhsFile
      && beforeOrConcurrent lhsEvent rhsEvent
  end.

Definition isSound (timeline: Timeline) (disk: Disk) :=
  exists (files: list File),
    let eventFiles := combine timeline files in
    let staggered := combine eventFiles (skipn 1 eventFiles) in
    length eventFiles = length timeline
    /\ forall (pair: ((Event*File)*(Event*File))),
        In pair staggered -> isSoundPair disk pair = true.

Definition isSound_compute (timeline: Timeline) (disk: Disk) 
  (files: list File) :=
  let eventFiles := combine timeline files in
  let staggered := combine eventFiles (skipn 1 eventFiles) in
  beq_nat (length eventFiles) (length timeline)
  && forallb (isSoundPair disk) staggered.

Lemma isSound_reflection (timeline: Timeline) (disk: Disk)
  (files: list File) :
  isSound_compute timeline disk files = true ->
    isSound timeline disk.
Proof.
  intros. unfold isSound. exists files.
  unfold isSound_compute in H.
  apply Bool.andb_true_iff in H. destruct H. 
  split. apply beq_nat_eq. auto.
  apply forallb_forall. auto.
Qed.
