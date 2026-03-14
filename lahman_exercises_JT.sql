/*## Lahman Baseball Database Exercise
- this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
- you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)

1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. 
Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?*/

-- My work, i trippled the salary on accident
SELECT
	p.namefirst,
	p.namelast,
	SUM(s.salary) AS total_salary
FROM
	people p
LEFT JOIN collegeplaying cp
    ON
	p.playerid = cp.playerid
LEFT JOIN schools sc
    ON
	cp.schoolid = sc.schoolid
INNER JOIN salaries s
    ON
	p.playerid = s.playerid
WHERE
	sc.schoolname = 'Vanderbilt University'
GROUP BY
	p.playerid,
	p.namefirst,
	p.namelast
ORDER BY
	total_salary DESC;

-- correct method
WITH vandy_players AS (
SELECT
	DISTINCT playerid
FROM
	collegeplaying
WHERE
	schoolid = 'vandy'
)
SELECT
	p.namefirst || ' ' || p.namelast AS full_name,
	SUM(salary)::NUMERIC::MONEY AS total_earnings
FROM
	salaries s
INNER JOIN vandy_players v
ON
	s.playerid = v.playerid
INNER JOIN people p
ON
	s.playerid = p.playerid
GROUP BY
	full_name
ORDER BY
	total_earnings DESC;

/*2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", 
  and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.*/

--i did it correctly
SELECT 
	CASE 
		WHEN pos = 'OF' THEN 'Outfield'
		WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
		WHEN pos IN ('P', 'C') THEN 'Battery'
	END AS position_group,
	SUM(po) AS total_putouts
FROM fielding 
WHERE yearid = 2016
GROUP BY position_group;

/*3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? 
 (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, 
 check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)*/

--my work
SELECT 
	(yearid/10)*10 || 's' AS decade,
	ROUND(AVG(so/ g), 2) AS average_strikeouts_per_game,
	ROUND(AVG(hr/ g), 2) AS average_home_runs_per_game
FROM teams
WHERE yearid >= 1920
GROUP BY decade
ORDER BY decade;

--correct method
WITH decades AS (
SELECT
	*
FROM
	generate_series(1920, 2016, 10) AS decade_start
)
SELECT
	decade_start || 's' AS decade,
	ROUND(SUM(so) * 1.0 / (SUM(g) / 2.0), 2) AS so_per_game,
	ROUND(SUM(hr) * 1.0 / (SUM(g) / 2.0), 2) AS hr_per_game
FROM
	teams t
INNER JOIN decades d
ON
	t.yearid BETWEEN d.decade_start AND d.decade_start + 9
WHERE
	yearid >= 1920
GROUP BY
	decade
ORDER BY
	decade;

/*4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful.
  (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, 
  number of stolen bases, number of attempts, and stolen base percentage.*/

SELECT
	p.namefirst,
	p.namelast,
	b.sb AS stolen_bases,
	(b.sb + b.cs) AS attempts,
	ROUND((b.sb::NUMERIC / (b.sb + b.cs)) * 100, 1) || '%' AS stolen_base_percentage
FROM
	batting b
INNER JOIN people p
    ON
	b.playerid = p.playerid
WHERE
	b.yearid = 2016
	AND (b.sb + b.cs) >= 20
ORDER BY
	stolen_base_percentage DESC
LIMIT 1;

--could have done a CTE

/*5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? 
 Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year.
 How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?*/

SELECT
	MAX(w) AS most_wins_without_ws
FROM
	teams
WHERE
	yearid BETWEEN 1970 AND 2016
	AND wswin <> 'Y';
--116 wins and no world series champion

SELECT
	MIN(w) AS least_wins_with_ws
FROM
	teams
WHERE
	yearid BETWEEN 1970 AND 2016
	AND wswin = 'Y';
--63 wins with a worlds series champion

Ï
--unusually low was 1981

SELECT
	MIN(w) AS fewest_wins_ws_champion
FROM
	teams
WHERE
	yearid BETWEEN 1970 AND 2016
	AND yearid <> 1981
	AND wswin = 'Y';
-- 83 wins was not unusually low to win the world series



/*6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.*/

SELECT
	p.namelast,
	p.namefirst,
	am.lgid,
	am.awardid
FROM
	people p
INNER JOIN awardsmanagers am
	ON
	p.playerid = am.playerid
WHERE
	am.awardid LIKE 'T%'
	AND am.playerid IN (
	SELECT
		playerid
	FROM
		awardsmanagers
	WHERE
		awardid LIKE 'T%'
		AND lgid IN ('AL', 'NL')
	GROUP BY
		playerid
	HAVING
		count(DISTINCT lgid) = 2
			)
ORDER BY
	p.namelast;

/*7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). 
 Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.*/

SELECT
	pe.namefirst || ' ' || pe.namelast AS full_name,
	sum(p.so) AS strike_outs_total,
	sum(p.gs) AS games_started,
	sum(s.salary) AS total_salary,
	round(sum(s.salary)::NUMERIC / sum(p.so), 2) AS salary_per_strikeout
FROM
	pitching p
JOIN salaries s
ON
	p.playerid = s.playerid
	AND p.yearid = s.yearid
JOIN people pe
ON 	
	p.playerid = pe.playerid
WHERE
	p.yearid = 2016
GROUP BY 
	full_name 
HAVING
	sum(p.gs) >= 10
ORDER BY
	salary_per_strikeout DESC;
	

/*8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame 
 (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column 
 of the halloffame table.*/

WITH hits_over_3000 AS (
SELECT
	b.playerid,
	sum(b.h) AS career_hits
FROM
	batting b
GROUP BY
	b.playerid
ORDER BY
	career_hits DESC
)
SELECT
	p.namelast,
	p.namefirst,
	h.career_hits,
	hf.yearid AS hall_of_fame_year
FROM
	hits_over_3000 h
JOIN people p
ON
	h.playerid = p.playerid
LEFT JOIN halloffame hf
ON
	h.playerid = hf.playerid
	AND hf.inducted = 'Y'
WHERE
	career_hits >= 3000
ORDER BY
	h.career_hits DESC;

/*9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.*/

SELECT
	p.namefirst,
	p.namelast
FROM
	(
	SELECT
		playerid
	FROM
		(
		SELECT
			b.playerid,
			b.teamid,
			sum(b.h) AS team_hits
		FROM
			batting b
		GROUP BY
			b.playerid,
			b.teamid
		HAVING
			sum(b.h) >= 1000
)
	GROUP BY
		playerid
	HAVING
		count(teamid) >= 2 )
players
JOIN people p 
ON
	players.playerid = p.playerid
ORDER BY
	p.namelast;

/*10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home 
 run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.*/

WITH career_hr AS 
(
SELECT
	b.playerid,
	max(b.hr) AS career_max_homeruns,
	count(DISTINCT b.yearid) AS seasons_played
FROM
	batting b
GROUP BY
	b.playerid
)
SELECT
	p.namefirst,
	p.namelast,
	b.hr AS hr_2016
FROM
	batting b
JOIN career_hr AS c 
ON
	b.playerid = c.playerid
JOIN people p
ON
	b.playerid = p.playerid
WHERE
	b.yearid = 2016
	AND b.hr = c.career_max_homeruns
	AND b.hr > 0
	AND c.seasons_played >= 10
ORDER BY
	hr_2016 DESC;



/*After finishing the above questions, here are some open-ended questions to consider.

**Open-ended questions**

11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole 
league tend to increase together, so you may want to look on a year-by-year basis.

12. In this question, you will explore the connection between number of wins and attendance.

    a. Does there appear to be any correlation between attendance at home games and number of wins?  
    b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.


13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame