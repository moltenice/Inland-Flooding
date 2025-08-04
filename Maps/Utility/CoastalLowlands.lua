include "TerrainGenerator"
--#######################################
--Inland flooding by Nerevatar
--#######################################

-- Marks Coastal Lowlands for Civ VI XP2
--    These are areas that are susceptible to coastal flooding from XP2 environmental effects

function IsValidCoastalLowland(plot)
	local adjPlotPrio = false;
	-- for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		-- local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
		-- if (adjacentPlot ~= nil) then
			
			-- local adjFeatureType = adjacentPlot:GetFeatureType();			

			-- -- if (adjacentPlot:IsWater()) then
				-- -- adjPlotPrio = true;				
			-- -- end
			-- -- if (adjacentPlot:IsCoastalLand()) then
				-- -- adjPlotPrio = true;				
			-- -- end
			-- -- if (adjFeatureType == g_FEATURE_MARSH) then
				-- -- adjPlotPrio = true;				
			-- -- end
		-- end
	-- end
	if (plot:IsCoastalLand() == true or plot:GetFeatureType() == g_FEATURE_MARSH or plot:IsRiver() or adjPlotPrio) then
		if (not plot:IsHills()) then
			if (not plot:IsMountain()) then
				if (not plot:IsNaturalWonder()) then
					if (not plot:IsWater()) then
						return true;
					end
				end
			end
		end
	end	
	return false;
end

-- TODO further map generation speed optimization could be done here by doing all adjecent plot lookups in this one loop instead of both here and in ScoreCoastalLowlandTiles()
function GetNumberAdjacentWaterAndLake(iX, iY)
	
	local iWaterCount = 0;
	local iLakeCount = 0;

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil and adjacentPlot:IsWater() == true) then
				iWaterCount = iWaterCount + 1;
		end
		if (adjacentPlot ~= nil and adjacentPlot:IsLake() == true) then
				iLakeCount = iLakeCount + 1;
		end
	end

	return iWaterCount, iLakeCount;
end

function ScoreCoastalLowlandTiles()
	
	aaScoredTiles = {};
	local iW, iH = Map.GetGridSize();
	for i = 0, (iW * iH) - 1, 1 do
		plot = Map.GetPlotByIndex(i);
		if (plot) then
			if (IsValidCoastalLowland(plot)) then
				local featureType = plot:GetFeatureType();
				local numAdjWater, numAdjLakes = GetNumberAdjacentWaterAndLake(plot:GetX(), plot:GetY());
				local iScore = 0;

			    -- An adjacent volcano or lake is also bad news --> seems like 0 is not enough, so changed to -200
				if (GetNumberAdjacentVolcanoes(plot:GetX(), plot:GetY()) > 0) then
					iScore = -200;
					

				-- All tiles are chosen based on the weightings in this section:
				else
					-- Start with a base Score					
					-- Coast is very high priority
					if (plot:IsCoastalLand() == true) then
						iScore = 255;
					elseif (featureType == g_FEATURE_MARSH) then
						iScore = 145;
					else						
						iScore = 5;
					end
					
					-- Lakes gets a boost from coastal + adj water, so this is reduced so lakes dont flood at stage 1. Additional check to stop tiles between lakes and coast from NOT flood
					if (numAdjLakes > 2 and numAdjLakes == numAdjWater) then
						iScore = 10;
					-- Small lakes gets a boost from coastal + adj water, so this is pre-substracted here. Additional check to stop tiles between lakes and coast from NOT flood
					elseif (numAdjLakes <= 2 and numAdjLakes > 0 and numAdjLakes == numAdjWater) then 
						iScore = -210;  -- Tiles next to lakes is considered "coastal" and as thus is valid for flooding under the current algorithm. To reduce lake flooding, this could be put further into the negative
					end
					
					-- Tiles with a River are prioritized heavily (to balance with the up-to-six occurrences of the factors below)
					if (plot:IsRiver()) then
						iScore = iScore + 75;
					end

					for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
						local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
						if (adjacentPlot ~= nil) then
							
							local adjFeatureType = adjacentPlot:GetFeatureType();

							-- Tiles near Marsh are highly prioritized
							if (adjFeatureType == g_FEATURE_MARSH) then
								iScore = iScore + 100;
							end
							-- Tiles near Floodplains are highly prioritized
							if (adjFeatureType == g_FEATURE_FLOODPLAINS or adjFeatureType == g_FEATURE_FLOODPLAINS_GRASSLAND or adjFeatureType == g_FEATURE_FLOODPLAINS_PLAINS) then
								iScore = iScore + 30;
							end

							-- Tiles near Hills or Mountains are deprioritized
							if (adjacentPlot:IsHills() or adjacentPlot:IsMountain()) then
								iScore = iScore - 75; --Reduce this? It currently prevents quite a bit of flooding in some cases
							end
							
							-- Adjecent plots with rivers give a small boost (only small since river are very "snakey" and we dont want inland lakes to flood at level 1)
							if (adjacentPlot:IsRiver()) then
								iScore = iScore + 15;
							end
							
							-- Adjecent coastal plots receive a large boost to make the first parts of a coastal river flood at stage 2
							if (adjacentPlot:IsCoastalLand() == true) then
								iScore = iScore + 85;    -- Maybe less?
							end
							
							-- Tiles with more adjacent Coast tiles are prioritized
							if (adjacentPlot:IsWater()) then

								-- If the water tile is a Natural Wonder (Dead Sea?) don't allow it (made by Firaxis - is there any reason for this once normal lakes can flood?)
								if (adjacentPlot:IsNaturalWonder()) then
									iScore = 0;
									break;
								else
									iScore = iScore + 30; 
								end
							end
						end
					end
				end

				if (iScore > 0) then
					row = {};
					row.MapIndex = i;
					row.Score = iScore;
					table.insert(aaScoredTiles, row);
				end
			end
		end
	end

	return aaScoredTiles;
end

function MarkCoastalLowlands()

	print("Map Generation - Marking Coastal Lowlands, with Nerevatar's Inland Flooding");

	-- Hardcoded to 100 instead of using global parameter, and setting that one to 100.
	-- This ugly fix is needed to not break primordial map script function MarkCoastalLowlands, where it would result in the engine attempting marking more tiles then available results in null/nil reference exceptions
	local numDesiredCoastalLowlandsPercentage = 100;--GlobalParameters.CLIMATE_CHANGE_PERCENT_COASTAL_LOWLANDS or 35;

	scoredTiles = ScoreCoastalLowlandTiles();
	
	-- Caps the number of floodable tiles to a maximum of ~17% of all tiles (incl. both water and land). Otherwise water-heavy maps could be almost completely wiped out
	local numScoredTiles = #scoredTiles;
	local iW, iH = Map.GetGridSize();
	if (numScoredTiles > ((iW * iH) / 6)) then
		numScoredTiles = ((iW * iH) / 6);
	end
	
	tilesToMark = math.floor((numScoredTiles * numDesiredCoastalLowlandsPercentage) / 100);
	
	if tilesToMark > 0 then
        table.sort (scoredTiles, function(a, b) return a.Score > b.Score; end);
		for tileIdx = 1, tilesToMark, 1 do
			local iElevation = 2;
			if (tileIdx <= tilesToMark / 4) then -- 25% highest scoring tiles get flooded first 
				iElevation = 0;
			elseif (tileIdx <= (tilesToMark * 5) / 8) then -- the next 37,5% highest scoring tiles get flooded second 
				iElevation = 1;
			end --the  remaining 37,5% tiles get flooded last 
			TerrainBuilder.AddCoastalLowland(scoredTiles[tileIdx].MapIndex, iElevation);
		end
		print(tostring(scoredTiles).." Coastal Lowland tiles scored");
		print(tostring(tilesToMark).." Coastal Lowland tiles added");
		print("  " .. tostring(GlobalParameters.CLIMATE_CHANGE_PERCENT_COASTAL_LOWLANDS) .. " percentage of eligible coastal tiles - from GlobalParameters.CLIMATE_CHANGE_PERCENT_COASTAL_LOWLANDS");
	end
end