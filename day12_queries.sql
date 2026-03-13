-- ============================================================
-- Day 12 SQL Assignment - Employee Database Queries
-- Dataset: Employee_data_v2.csv (474 rows)
-- Columns: id, gender, bdate, educ, jobcat, salary, salbegin, jobtime, prevexp, attrition
-- ============================================================

-- ============================================================
-- PART 1: BASIC SELECT / WHERE QUERIES (5 Queries)
-- ============================================================

-- Q1: Get all employees who are Managers
SELECT *
FROM employees
WHERE jobcat = 'Manager';

-- Q2: Get employees with salary greater than 50000
SELECT id, gender, jobcat, salary
FROM employees
WHERE salary > 50000;

-- Q3: Get female employees who have NOT left the company (attrition = 'No')
SELECT id, gender, jobcat, salary
FROM employees
WHERE gender = 'Female' AND attrition = 'No';

-- Q4: Get employees with education level of 16 or higher, sorted by salary descending
SELECT id, educ, jobcat, salary
FROM employees
WHERE educ >= 16
ORDER BY salary DESC;

-- Q5: Get employees whose starting salary was below 15000
SELECT id, gender, jobcat, salbegin, salary
FROM employees
WHERE salbegin < 15000
ORDER BY salbegin ASC;


-- ============================================================
-- PART 2: JOIN QUERIES (5 Queries)
-- Note: Since this is a single-table dataset, we simulate JOINs
-- using self-joins and subquery-based derived tables (common
-- interview pattern for single-table JOIN practice)
-- ============================================================

-- Q6: Self-join to find pairs of employees in the same job category
--     where the first has a higher salary than the second
SELECT a.id AS emp1_id, b.id AS emp2_id, a.jobcat, a.salary AS salary1, b.salary AS salary2
FROM employees a
JOIN employees b
  ON a.jobcat = b.jobcat
  AND a.salary > b.salary
  AND a.id < b.id
LIMIT 20;

-- Q7: Join employees table with a derived table of average salary per job category
SELECT e.id, e.jobcat, e.salary, avg_table.avg_salary
FROM employees e
JOIN (
    SELECT jobcat, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY jobcat
) AS avg_table
  ON e.jobcat = avg_table.jobcat
ORDER BY e.jobcat;

-- Q8: Join employees with a derived table of highest-earning employee per gender
SELECT e.id, e.gender, e.salary, top_earners.max_salary
FROM employees e
JOIN (
    SELECT gender, MAX(salary) AS max_salary
    FROM employees
    GROUP BY gender
) AS top_earners
  ON e.gender = top_earners.gender
  AND e.salary = top_earners.max_salary;

-- Q9: Join employees with a derived table to flag above/below average earners per jobcat
SELECT e.id, e.jobcat, e.salary, stats.avg_salary,
       CASE WHEN e.salary >= stats.avg_salary THEN 'Above Average' ELSE 'Below Average' END AS salary_status
FROM employees e
JOIN (
    SELECT jobcat, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY jobcat
) AS stats
  ON e.jobcat = stats.jobcat
ORDER BY e.jobcat, e.salary DESC;

-- Q10: Self-join to find employees who have the same education level and same job category
SELECT a.id AS emp1_id, b.id AS emp2_id, a.educ, a.jobcat
FROM employees a
JOIN employees b
  ON a.educ = b.educ
  AND a.jobcat = b.jobcat
  AND a.id < b.id
LIMIT 20;


-- ============================================================
-- PART 3: AGGREGATION QUERIES (5 Queries)
-- ============================================================

-- Q11: Count of employees by job category
SELECT jobcat, COUNT(*) AS total_employees
FROM employees
GROUP BY jobcat
ORDER BY total_employees DESC;

-- Q12: Average current salary and starting salary by gender
SELECT gender,
       ROUND(AVG(salary), 2)    AS avg_current_salary,
       ROUND(AVG(salbegin), 2)  AS avg_starting_salary
FROM employees
GROUP BY gender;

-- Q13: Min, Max, and Average salary grouped by job category
SELECT jobcat,
       MIN(salary) AS min_salary,
       MAX(salary) AS max_salary,
       ROUND(AVG(salary), 2) AS avg_salary
FROM employees
GROUP BY jobcat
ORDER BY avg_salary DESC;

-- Q14: Attrition count and percentage by job category
SELECT jobcat,
       COUNT(*) AS total,
       SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) AS left_company,
       ROUND(
           SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
       ) AS attrition_pct
FROM employees
GROUP BY jobcat
ORDER BY attrition_pct DESC;

-- Q15: Average education level grouped by job category and gender
SELECT jobcat, gender,
       ROUND(AVG(educ), 2) AS avg_education
FROM employees
GROUP BY jobcat, gender
ORDER BY jobcat, gender;


-- ============================================================
-- PART 4: ADVANCED SQL PROBLEMS (5 Queries)
-- ============================================================

-- A1: Running Total of Salary using Window Functions
--     Cumulative salary ordered by employee id, per job category
SELECT id,
       jobcat,
       salary,
       SUM(salary) OVER (
           PARTITION BY jobcat
           ORDER BY id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total_salary
FROM employees
ORDER BY jobcat, id;


-- A2: Top 3 Earners per Job Category using RANK()
SELECT *
FROM (
    SELECT id,
           gender,
           jobcat,
           salary,
           RANK() OVER (PARTITION BY jobcat ORDER BY salary DESC) AS salary_rank
    FROM employees
) AS ranked
WHERE salary_rank <= 3
ORDER BY jobcat, salary_rank;


-- A3: Month-over-Month Salary Growth using LAG()
--     Compares each employee's salary to the previous employee's salary
--     within the same job category (ordered by id as proxy for hire sequence)
SELECT id,
       jobcat,
       salary,
       LAG(salary) OVER (PARTITION BY jobcat ORDER BY id) AS prev_salary,
       salary - LAG(salary) OVER (PARTITION BY jobcat ORDER BY id) AS salary_diff,
       ROUND(
           (salary - LAG(salary) OVER (PARTITION BY jobcat ORDER BY id)) * 100.0
           / NULLIF(LAG(salary) OVER (PARTITION BY jobcat ORDER BY id), 0),
           2
       ) AS pct_change
FROM employees
ORDER BY jobcat, id;


-- A4: CTE for Multi-Step Calculation
--     Step 1: Compute avg salary per dept
--     Step 2: Compute salary growth ratio (current vs starting)
--     Step 3: Combine to show employees above-avg salary WITH high growth
WITH dept_avg AS (
    SELECT jobcat, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY jobcat
),
salary_growth AS (
    SELECT id,
           gender,
           jobcat,
           salary,
           salbegin,
           ROUND((salary - salbegin) * 1.0 / salbegin * 100, 2) AS growth_pct
    FROM employees
)
SELECT sg.id, sg.gender, sg.jobcat, sg.salary, sg.growth_pct, da.avg_salary,
       CASE WHEN sg.salary > da.avg_salary THEN 'Above Avg' ELSE 'Below Avg' END AS salary_status
FROM salary_growth sg
JOIN dept_avg da ON sg.jobcat = da.jobcat
ORDER BY sg.growth_pct DESC;


-- A5: Correlated Subquery for Employee-Department Comparison
--     Find all employees earning more than the average salary of their own job category
SELECT id,
       gender,
       jobcat,
       salary
FROM employees e
WHERE salary > (
    SELECT AVG(salary)
    FROM employees
    WHERE jobcat = e.jobcat
)
ORDER BY jobcat, salary DESC;
