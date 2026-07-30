--[[

	
This module is really meant as a starting place for your own work. 
I fully expect you to take it it and edit it.

What it is:

A framework to make it easy to have 100's of NPCs in your game.
* Very low server CPU, client CPU, and bandwidth
* Fast rendering on clients
* Custom replication
* Editable update rates for thinking and replication
* Custom culling (distance? zones?)
* Server script your actions and animations
* Comes with custom lowPoly R15 rigs for fast batching

This module is an NPC module for ultra-lightweight NPCs.
	* It implements its own replication layer for position, angle, and animations
	* It works with any NPC rig (either animator or humanoid, although the humanoid never runs on the server)
	* It doesn't participate in the physics system, relying on shapecasts for motion
	* It decouples replication rate from think rate, both of which are adjustable (eg: replication at 2hz, think at 10hz)
	* Fixed Low hz replication is augmented dynamic event insertion for animations or sudden motions eg: jumping
	* It has a .data blob for you to stick your own custom stuff in
	* It handles some basic stuff like hitpoints, death, jumping,
	* There is example code for pathfinding
	* It has example code for culling at range and sleeping if no players are nearby

How it works:

The server creates a npcRecord, and a real model (npcRecord.instance), and keeps the model in ReplicatedStorage
The client gets sent events about this instance, moves it to the workspace, loads animations onto it, and positions it around via unreliableRemotes
The server view of this instance never moves, or animates, or participates in physics in any way
However, any property changes (eg: color, adding a weapon etc) will be copied to clients via regular roblox replication.


How to create an NPC:

* create a config
* call CreateNPC with the config and the template character rig
* hook into the :onThink signals to drive the character around via scripts


About the default rigs:

Robert is a stock "R15" cleaned up to batch better

	Use him for large crowds
	does not use a humanoid. 
	does not support character apperances
	does batch!

Bob is a lowpoly version of Robert (get it?)

	Use him for *very* large crowds
	
StockR15Blocky is a stock R15 with no changes
	Has a humanoid so can still use LoadCharacterAppearance etc
	Doesn't batch well (~ 2 drawcalls each because of the nametags + fastcluster)


Todo: 
	Teleport
	Spawn Angle
	Crowd Bumping (push other npcs away)
	Udp - (should be easy, npc data is stateless!)
	Initial Animation State (eg: spawned npcs to new players need their preserved animations)
 	Ragdolling (?)
	Fetch NPC by part API
]]
--
