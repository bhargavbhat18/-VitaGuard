from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict, List
import json
router = APIRouter()
connections: Dict[str, List[WebSocket]] = {}

async def broadcast_vitals(user_id: str, data: dict):
    if user_id in connections:
        dead=[]
        for ws in connections[user_id]:
            try:
                payload={k:(str(v) if hasattr(v,'isoformat') else v) for k,v in data.items()}
                await ws.send_text(json.dumps(payload))
            except: dead.append(ws)
        for ws in dead: connections[user_id].remove(ws)

@router.websocket("/ws/vitals/{user_id}")
async def vitals_ws(websocket: WebSocket, user_id: str):
    await websocket.accept()
    connections.setdefault(user_id,[]).append(websocket)
    try:
        while True: await websocket.receive_text()
    except WebSocketDisconnect:
        if user_id in connections and websocket in connections[user_id]:
            connections[user_id].remove(websocket)
