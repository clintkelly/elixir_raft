# ElixirRaft

Janky implementation of the [Raft consensus algorithm](https://raft.github.io/), written in
[Elixir](https://elixir-lang.org/).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elixir_raft` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:elixir_raft, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elixir_raft](https://hexdocs.pm/elixir_raft).

## Outline of the protocol

(All of this is taken from "In Search of an Understandable Consensus Algorithm (Extended Version)"
by Ongaro and Ousterhout.)

Every server can be in one of three states:

1. Leader
2. Follower
3. Candidate

Under normal operation, there is a single leader and the rest of the servers are followers.

Time is divided into *terms*. Each term begins with an election. The candidate that wins the
election is the leader for the rest of the term. (If there is a split vote, then there is a new term
and new election.)

Each server has a *current term number*, which increases monotonically with time. Severs exchange
terms when they pass messages; a server with a lower term can update its term to the latest when it
receives a message with a greater term.

A candidate or leader that discovers its term is out of date immediately becomes a follower.

If a server receives a request with a stale term number, it rejects the request.

## Messages

There are only two kinds of RPCs.

*RequestVote* RPCs. Initiated by candidates during an election.

*AppendEntries* RPCs. Initiated by leaders to replicate log entries and provide a heartbeat.

There are also special messages for transferring snapshots.

Servers retry RPCs that don't receive a response and issue RPCs in parallel.


## Safety guarantees

Election Safety: at most one leader can be elected in a given term. §5.2

Leader Append-Only: a leader never overwrites or deletes entries in its log; it only appends new
entries. §5.3

Log Matching: if two logs contain an entry with the same index and term, then the logs are identical
in all entries up through the given index. §5.3

Leader Completeness: if a log entry is committed in a given term, then that entry will be present in
the logs of the leaders for all higher-numbered terms. §5.4

State Machine Safety: if a server has applied a log entry at a given index to its state machine, no
other server will ever apply a different log entry for the same index. §5.4.3

## Election

Every server starts as a follower and stays a follower as long as it receives heartbeat RPCs. If it
does not receive any heartbeat RPCs for a duration called *election timeout* then it kicks off an
election:

1. Increment term
2. Move to candidate state
3. Issue RequestVote RPCs to all other servers

Then it either:

- wins the election
- receives a heartbeat from another leader (with term >= this candidate's term)
- there is a split election

Election timeouts are chosen randomly from a fixed internal (e.g., 150-300ms) to prevent split
elections.

## Log replication

Clients send requests (for state machine operations) to any server. Follower servers forward the
requests to the leader.

The leader appends the request to its log as a new entry and sends AppendEntries RPCs to all other
servers.

When the entry has been safely replicated, the leader applies the entry to its state machine and
return the result to the client. The entry is then said to be *committed.*

A committed entry is replicated on a majority of servers. If a given entry is committed, all of the
preceeding entries in the leader's log are also committed.

The leader tracks the highest index that is committed and includes that in AppendEntries RPCs (even
heartbeats). When a follower sees that a log entry is committed, it applies the entry to its local
state machine.

The leader will retry the AppendEntries RPCs indefinitely until every other server has stored the
log entries.

Every log is a list of state machine commands. Each entry in the log contains:

1. An index in the list
2. A term
3. The state machine operation itself

### The Log Matching Property (invariants for logs)

1.  If two entries in different logs have the same index and term, then they store the same command.
2.  If two entries in different logs have the same index and term, then the logs are identical in all
    preceeding entries.

How we ensure the second invariant: When the leader sends an AppendEntries RPC for a new entry, it
includes the index and term of the preceeding entry in its log. If a follower receives such an RPC
and sees a mistmatch in index and term, it refuses the new entries.

### Inconsistencies in logs

Inconsistencies should occur only when the leader or follower crashes.

A leader makes a follower's log consistent with its own by:

- finding the latest entry where the two logs agree
- deleting all later entries on the follower
- sending the follower all of the subsequent entries from the leader's log


## State to store on servers

### Persistent

(Should be stored on stable storage before responding to RPC)

- `current_term` - The latest term the server has seen.
- `voted_for` - ID of candidate for which this server voted in the current term.
- `log[]` - List of log entries `{command, term}`

### Volatile

- `commit_index` - Index of highest log entry known to be committed.
- `last_applied` - Index of highest log entry applied to state machine.

### Volatile (leader only)

- `next_index[]` - For each server, index of next log entry to send to that server. If all servers
    are consistent, then the `next_index` will be the last log index of the leader `+ 1`.
- `matching_index[]` - For each server, index of highest log entry known to be replicated on that
    server.

## RPCs

### AppendEntries

Sent by leader. Used to replicate log entries or as a heartbeat.

Request fields:

- `term` - Leader's term
- `leader_id` - Sender's ID
- `prev_log_index` - Index of the log entry preceeding new ones
- `prev_log_term` - Term of the log entry preceeding new ones
- `entries[]` - New log entries to store (empty for heartbeat)
- `leader_commit_index` - The leader's commit index

Response fields:

- `term` - Current term of the follower (for leader to update itself)
- `success?` - True if follower contained entry at `prev_log_index` with term `prev_log_term`.

Receiver implementation:

1. Reply false if `term < current_term` (sender is no longer the leader)
2. Reply false if `log[prev_log_index]` DNE or `log[prev_log_index].term != prev_log_term`
   (inconsistency between leader's and follower's logs)
3. If existing entry conflicts with a new one (from `entries[]`), delete the existing entry
   ("conflicts" means same index but different term)
4. Append new entries not in the log.
5. If `leader_commit_index > commit_index`, update `commit_index` to the min of
   `leader_commit_index` and the index of the last new entry copied from `entries[]`.

### RequestVote

Request fields:

- `term` - candidate's term
- `candidate_id` - Sender's ID
- `last_log_index` - Index of candidate's last log entry
- `last_log_term` - Term of candidate's last log entry

Reply fields:

- `term` - Candidate can update its `current_term`
- `vote_granted?` - Whether to vote for the server requesting the vote.

Receiver implementation:

- Reply false if `term < current_term`
- Grant vote if `voted_for == null` (haven't voted for anyone yet this term) and candidate's log is
    at least as up-to-date as receiver's log.


## Rules for servers

### All servers

- If `commit_index > last_applied`, update the state machine and `last_applied`.
- If any RPC request / response includes a `term > current_term`, update `current_term`.


### Followers

- Respond to RPCs from leaders and candidates!
- If election timeout elapses without getting AppendEntries RPC from leader or granting a vote to a
    candidate, the convert to candidate.

### Candidates

- When a server becomes a candidate:
  - increment `current_term`
  - vote for self
  - reset election timer
  - send RequestVote RPCs to all other servers
- got votes from majority of servers? become the leader!
- receive AppendEntries RPC from new leader? become a follower!
- election timeout expires - start a new election

### Leaders

A leader should never overwrite or delete entries in its own log. It only appends new entires.

There should be no more than one leader at any time.

- After election:
  - send initial empty AppendEntries RPC to each server
  - repeat during any idle periods to prevent timeouts
- receive command from client:
  - append entry to local log
  - respond to client *after* entry is applied to state machine
- if `len(log) >= next_index[follower]`:
  - follower is out of date
  - send AppendEntires RPC with log entries starting at `next_index[follower]`
      - succes? update `next_index[follower]` and `match_index[follower]`
      - fail because of log inconsistency? decrement `next_index[follower]` and try again
- update `commit_index` to `N` if:
  - `N > commit_index` (there is a reason to update `commit_index`)
  - majority of `match_index[i] >= N` (new entires replicated to quorum)
  - `log[N].term == current_term`

