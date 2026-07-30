local module = {}

--Animations are handled a little differently
--Because we can have variations and we want to synchronize those across all clients
-- we unroll animations into a single flat index list on clients
--The original tree strucutre is preserved on servers.
--If you see index, that refers to the index list.

export type AnimEntry = {
	id: string,
	weight: number,
	characterWalkSpeed: number?,
	speed: number?,
	--Filled out at runtime
	index: number?,
	track: AnimationTrack?,
	name: string?,
}

export type SourceAnimTable = {
	[string]: { AnimEntry },
}

export type FinalAnimTable = {
	sourceAnimTable: SourceAnimTable,
	animationsByIndex: { [number]: AnimEntry },
}

function module:BuildFinalAnimationTable(sourceAnimTable: SourceAnimTable): FinalAnimTable
	local animationTable: FinalAnimTable = {
		sourceAnimTable = sourceAnimTable,
		animationsByIndex = {},
	}

	--unroll it
	local index = 1
	for animName, animList in sourceAnimTable do
		for _, record in animList do
			animationTable.animationsByIndex[index] = record
			record.index = index
			record.name = animName
			index += 1
		end
	end

	return animationTable
end

return module
