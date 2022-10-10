--Deleting columns to reduce the information needed to be seen on a final league table
ALTER TABLE league_table
DROP COLUMN [pts/mp], [xg], [xgd], [xga], [xgd/90]


--Populate nation
SELECT *
FROM player_info
WHERE nation IS NULL or nation = ''

UPDATE player_info
SET nation = 'unknown' FROM player_info WHERE nation IS NULL or nation = ''


--Populate player stats data for Min, 90s, Gls, ast, G-PK, PK, PKatt, CrdY, CrdR, Gls, Ast, G+A, G-PK, G+A-PK, xG, npxG, xA, npxG+xA, xG, xA, xG+xA, npxG, npxG+xA

SELECT *
FROM player_stats

UPDATE player_stats
SET min = ISNULL(min, 0), [90s] = ISNULL([90s], 0), Gls = ISNULL(Gls, 0), ast = ISNULL(ast, 0), [g-pk] = ISNULL([g-pk], 0), pk = ISNULL(pk, 0), pkatt = ISNULL(pkatt, 0), crdy = ISNULL(crdy, 0), crdr = ISNULL(crdr, 0),
gls1 = ISNULL(gls1, 0), ast1 = ISNULL(ast1, 0), [g+a] = ISNULL([g+a], 0), [g-pk1] = ISNULL([g-pk1], 0), [G+A-PK] = ISNULL([G+A-PK], 0), xg = ISNULL(xg, 0) ,npxG = ISNULL(npxG, 0), xa = ISNULL(xa, 0),
[npxG+xA] = ISNULL([npxG+xA], 0), xG1 = ISNULL(xG1, 0), xA1 = ISNULL(xA1, 0), [xg+xa] = ISNULL([xg+xa], 0), npxg1 = ISNULL(npxg1, 0), [npxG+xA1] = ISNULL([npxG+xA1], 0)



--Total number of players in the league
SELECT COUNT(*) as 'TotalPlayers'
FROM player_info;


--Number of players in each team
SELECT club, count(*) as 'Players'
FROM player_info
GROUP BY club
ORDER BY count(*) DESC


--Nationalities and the number of players
SELECT nation, COUNT(*) as 'Players'
FROM player_info
GROUP BY nation
ORDER BY [players] DESC



--Number of different Nationalities in each team, Watford has players from 22 different Nationalities
SELECT club, COUNT( DISTINCT nation ) as 'DifferentNationalities'
FROM player_info
GROUP BY club
ORDER BY COUNT( DISTINCT nation ) DESC



--Number of English players playing in each team
SELECT club, count(*) as 'EnglishPlayers'
FROM player_info
WHERE nation = 'ENG'
GROUP BY club



--Players who have never played during the league
SELECT player_info.club, player_info.player
FROM player_info JOIN player_stats 
ON player_info.player = player_stats.player
WHERE player_stats.min = 0;


--Number of players that have never played in each team
SELECT player_info.club, COUNT(*) as 'Players'
FROM player_info JOIN player_stats 
ON player_info.player = player_stats.player
WHERE player_stats.min = 0
GROUP BY player_info.club, player_stats.min


--Top Goal Scorer(s)
SELECT player_info.Club, player_stats.Player, gls as 'GoalsScored'
FROM player_info JOIN player_stats 
ON player_info.player = player_stats.player
WHERE gls = ( SELECT MAX( gls ) FROM player_stats )



--Most Assists
SELECT player_info.Club, player_stats.Player, ast as 'Assists'
FROM player_info JOIN player_stats 
ON player_info.player = player_stats.player
WHERE ast = ( SELECT MAX( ast ) FROM player_stats )



--Players who have played every match
SELECT player_stats.Player
FROM player_stats
WHERE mp = (SELECT MAX( mp ) FROM league_table)



--Most attendance from the league
SELECT squad, attendance
FROM league_table
WHERE attendance = (SELECT MAX(attendance) FROM league_table)

/* OR

SELECT TOP 1 squad, attendance
FROM league_table
ORDER BY Attendance DESC
*/



--Add a new column TopGoalScorer to league_table and populate with the top goal scorer from each club
SELECT *
FROM league_table

ALTER TABLE league_table
ADD TopGoalScorer NVARCHAR(255)



CREATE VIEW TopGoalsScorer as (
SELECT RANK() OVER (PARTITION BY player_info.club ORDER BY gls DESC) as 'ranks', player_info.club as 'Club', player_info.Player as 'Player', gls as 'Goals'
FROM player_info JOIN player_stats 
ON player_info.player = player_stats.player
JOIN league_table ON league_table.Squad = player_info.Club
) 


UPDATE league_table
SET topgoalscorer = player FROM TopGoalsScorer WHERE league_table.Squad = Club and ranks = 1

--Add a new column MostAssists to league_table and populate with the player with the most assists from each club
ALTER TABLE league_table
ADD MostAssists NVARCHAR(255)

CREATE VIEW MostAssists as (
SELECT player_info.Club as 'Club', player_info.Player as 'Player', ast as 'Assists', RANK() OVER (PARTITION BY player_info.club ORDER BY ast DESC) as 'ranks'
FROM player_info JOIN player_stats 
ON player_info.player = player_stats.player
) 

UPDATE league_table
SET MostAssists = player FROM MostAssists WHERE league_table.Squad = Club and ranks = 1


--Percentage of goals scored from players for their club if they have scored at least one goal
SELECT league_table.Squad, league_table.gf as 'TotalGoalsScored', player_stats.Player, gls as 'Goals', ROUND( gls / gf * 100 , 2) as 'Percentage'
FROM league_table JOIN player_info
ON league_table.Squad = player_info.Club
JOIN player_stats ON player_info.Player = player_stats.Player
WHERE gls >= 1
ORDER BY squad, Percentage DESC




--Teams that scored more but finished lower

SELECT lt1.Position, lt1.Squad, lt1.GF as 'GoalsFor', lt2.Position, lt2.Squad, lt2.GF as 'GoalsFor'
FROM league_table lt1, league_table lt2
WHERE lt1.Position > lt2.Position and lt1.gf > lt2.gf
ORDER BY lt1.Position




--Teams that conceded more but finished higher

SELECT lt1.Position, lt1.Squad, lt1.ga as 'GoalsAgainst', lt2.Position, lt2.Squad, lt2.ga as 'GoalsAgainst'
FROM league_table lt1, league_table lt2
WHERE lt1.Position < lt2.Position and lt1.ga > lt2.ga
ORDER BY lt1.Position




--Players that played in more than 1 team during the season
WITH Transfer_CTE(PlayerName, Club1, Club2, row_num) AS
(
	SELECT DISTINCT pi1.player, pi1.club as 'club1', pi2.club as 'club2', ROW_NUMBER() OVER(PARTITION BY pi1.player ORDER BY pi1.player) as row_num
FROM player_info pi1, player_info pi2
WHERE pi1.club != pi2.Club and pi1.Player = pi2.Player
)

SELECT PlayerName, club1, club2
FROM Transfer_CTE
WHERE row_num = 1


--Teams European competiton league placing and relegation status depending on where they finished in the league
ALTER TABLE league_table
ADD [Status] nvarchar(255)

SELECT *
FROM league_table

UPDATE league_table
SET [status] = CASE WHEN position IN (1,2,3,4) THEN 'UEFA Champion League'
			WHEN position IN (5,6) THEN 'Europa League'
			WHEN position = 7 THEN 'Europa Conference League'
			WHEN position IN (SELECT TOP 3 position FROM league_table ORDER BY position DESC) THEN 'Relegated'
			ELSE ''
			END
		FROM league_table

/*I have added a new column after MP (matches played) called Record through league_table database design as I wanted to place it after MP.
If position of the column did not matter, add it with the following below or in mysql can use ADD COLUMN name AFTER columnName
ALTER TABLE league_table
ADD WinDrawLoss nvarchar(255)*/

UPDATE league_table
SET [Record] = CAST(W as nvarchar) + '-' + CAST(D as nvarchar) + '-' + CAST(L as nvarchar)
