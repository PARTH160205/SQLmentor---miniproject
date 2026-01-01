use sqlmentor;

CREATE TABLE user_submissions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT,
    question_id INT,
    points INT,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(50)
);

SELECT * FROM user_submissions;

-- Q.1 List all distinct users and their stats (return user_name, total_submissions, points earned)

SELECT 
    username,
    COUNT(id) AS total_submissions,
    SUM(points) AS points_earned
FROM
    user_submissions
GROUP BY username
ORDER BY points_earned ASC;

-- Q.2 Calculate the daily average points for each user.

SELECT 
    DATE(submitted_at) AS day,
    username,
    AVG(points) AS daily_avg_points
FROM
    user_submissions
GROUP BY DATE(submitted_at) , username
ORDER BY username;

-- Q.3 Find the top 3 users with the most correct submissions for each day.
WITH daily_submissions AS (                               -- CTE to calculate daily correct submissions per user

    SELECT                                                   -- Select required fields for daily analysis
        DATE(submitted_at) AS daily,                         -- Extract only date from timestamp for daily grouping
        username,                                            -- Username of the user
        SUM(CASE                                             -- Conditional aggregation to count correct submissions
            WHEN points > 0 THEN 1                           -- Count submission as correct if points are greater than 0
            ELSE 0                                           -- Otherwise count as incorrect
        END) AS correct_submissions                          -- Alias for total correct submissions per day
    FROM user_submissions                                    -- Source table containing submission data
    GROUP BY DATE(submitted_at), username                    -- Group data by date and user

),

users_rank AS (                                             -- CTE to rank users per day

    SELECT                                                   -- Select ranked user data
        daily,                                               -- Submission date
        username,                                            -- Username
        correct_submissions,                                 -- Number of correct submissions
        DENSE_RANK() OVER (                                  -- Window function to assign rank
            PARTITION BY daily                               -- Restart ranking for each day
            ORDER BY correct_submissions DESC                -- Rank users by highest correct submissions
        ) AS user_rank                                       -- Alias for ranking column
    FROM daily_submissions                                   -- Use aggregated daily submission data

)

SELECT                                                       -- Final output query
    daily,                                                   -- Date of submission
    username,                                                -- Username of top performer
    correct_submissions                                      -- Correct submissions count
FROM users_rank                                              -- Fetch data from ranked CTE
WHERE user_rank <= 3                                         -- Filter to keep only top 3 users per day
ORDER BY daily, correct_submissions DESC;                    -- Sort results by date and performance

-- Q.4 Find the top 5 users with the highest number of incorrect submissions.
SELECT                                                          -- Select aggregated submission statistics per user
    username,                                                   -- Username of the user

    SUM(CASE                                                    -- Count total incorrect submissions
        WHEN points < 0 THEN 1                                 -- Increment count if submission has negative points
        ELSE 0                                                 -- Otherwise do not count
    END) AS incorrect_submissions,                              -- Alias for incorrect submission count

    SUM(CASE                                                    -- Count total correct submissions
        WHEN points > 0 THEN 1                                 -- Increment count if submission has positive points
        ELSE 0                                                 -- Otherwise do not count
    END) AS correct_submissions,                                -- Alias for correct submission count

    SUM(CASE                                                    -- Calculate total points lost from incorrect submissions
        WHEN points < 0 THEN points                            -- Add negative points for incorrect submissions
        ELSE 0                                                 -- Ignore non-negative points
    END) AS incorrect_submissions_points,                      -- Alias for total incorrect points

    SUM(CASE                                                    -- Calculate total points earned from correct submissions
        WHEN points > 0 THEN points                            -- Add points for correct submissions
        ELSE 0                                                 -- Ignore non-positive points
    END) AS correct_submissions_points_earned,                 -- Alias for total correct points earned

    SUM(points) AS points_earned                                -- Calculate net total points earned by the user

FROM user_submissions                                          -- Source table containing all user submissions

GROUP BY username                                              -- Group data by user to calculate per-user statistics

ORDER BY incorrect_submissions DESC;                           -- Sort users by highest number of incorrect submissions


-- Q.5 Find the top 10 performers for each week.

SELECT *                                                     -- Select final filtered results
FROM (
    SELECT
        YEAR(submitted_at) AS year_no,                       -- Extract year to avoid week overlap across years
        WEEK(submitted_at, 1) AS week_no,                    -- Extract ISO week number (Monday as first day)
        username,                                            -- Username of the user
        SUM(points) AS total_points_earned,                  -- Total points earned by user in that week
        DENSE_RANK() OVER (                                  -- Rank users based on weekly points
            PARTITION BY YEAR(submitted_at), WEEK(submitted_at, 1)
            ORDER BY SUM(points) DESC
        ) AS user_rank                                       -- Rank column
    FROM user_submissions                                    -- Source table
    GROUP BY YEAR(submitted_at), WEEK(submitted_at, 1), username
) AS weekly_rank                                            -- Alias required for subquery in MySQL
WHERE user_rank <= 10                                        -- Keep only top 10 users per week
ORDER BY year_no, week_no, total_points_earned DESC;         -- Sort output
