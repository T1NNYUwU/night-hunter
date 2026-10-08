"""The house graph, exported from the game's HouseGraph.luau (house_graph.json).

Node ids are 1-based like in Luau; index 0 of every list is unused so ids can be used directly.
"""

from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

GRAPH_FILE = Path(__file__).with_name("house_graph.json")


@dataclass(frozen=True)
class Node:
    id: int
    kind: str  # "room" | "hide"
    room: int


@dataclass(frozen=True)
class HouseGraph:
    signature: str
    room_count: int
    nodes: list[Node | None]  # nodes[id]
    neighbors: list[list[int]]  # neighbors[id]
    dist: list[list[int]]  # dist[a][b] = hops

    @property
    def node_count(self) -> int:
        return len(self.nodes) - 1


def _bfs(neighbors: list[list[int]], source: int, n: int) -> list[int]:
    dist = [10**9] * (n + 1)
    dist[source] = 0
    queue = deque([source])
    while queue:
        u = queue.popleft()
        for v in neighbors[u]:
            if dist[v] > dist[u] + 1:
                dist[v] = dist[u] + 1
                queue.append(v)
    return dist


def build(data: dict) -> HouseGraph:
    raw_nodes = data["nodes"]
    n = len(raw_nodes)
    nodes: list[Node | None] = [None] * (n + 1)
    for item in raw_nodes:
        nodes[item["id"]] = Node(item["id"], item["kind"], item["room"])
    neighbors = [[]] + [list(row) for row in data["neighbors"]]
    dist = [[]] + [_bfs(neighbors, s, n) for s in range(1, n + 1)]
    return HouseGraph(data["signature"], data["roomCount"], nodes, neighbors, dist)


@lru_cache(maxsize=1)
def load() -> HouseGraph:
    return build(json.loads(GRAPH_FILE.read_text(encoding="utf-8")))
