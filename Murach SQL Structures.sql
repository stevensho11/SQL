/*******************************************************
* Case Study: Murach College
* Stevens Ho
* 
* Compilation of various functions, triggers, ad hoc queries, and stored procedures to allow users to access, extract, and manipulate data from
* the database
********************************************************/

/***********************************************************************/
/* This is a script that creates and calls a stored procedure named spInsertInstructor that inserts a row into the
/* the Instructors table.
/***********************************************************************/

IF OBJECT_ID('spInsertInstructor') IS NOT NULL
	DROP PROC spInsertInstructor
GO
CREATE PROC spInsertInstructor
	(
		@LastName varchar(25),
		@FirstName varchar(25),
		@Status char(1),
		@DeptChair bit,
		@AnnualSalary money,
		@DeptID int
	)
AS
IF @AnnualSalary < 0 --validate that AnnualSalary is not negative
	THROW 50001, 'AnnualSalary cannot be a negative number.', 1;
IF @Status != 'F' AND @Status != 'P' --validate that Status can only be F or P
	THROW 50001, 'Please specify either "F" for full-time or "P" for part-time.', 1;
IF @DeptID > 7 OR @DeptID < 1 --validate that DeptID specifies an actual Dept in the database
	THROW 50001, 'That DeptID is invalid. Please specify a DeptID between 1-7 inclusive.', 1;
BEGIN
DECLARE @DateAdded date = CAST(CURRENT_TIMESTAMP AS DATE);

INSERT Instructors
VALUES(@LastName, @FirstName, @Status,
		@DeptChair, @DateAdded, @AnnualSalary,
		@DeptID);
RETURN @@IDENTITY;
END

/***********************************************************************/
/* This is a script that creates and calls a function named fnTuition that calculates the total tuition for a student. 
/***********************************************************************/


IF OBJECT_ID('fnTuition') IS NOT NULL
	DROP FUNCTION fnTuition
GO
CREATE FUNCTION fnTuition
(
	@StudentID INT
)
RETURNS MONEY
AS 
BEGIN

	DECLARE @SumCourseUnits AS INT
	DECLARE @Tuition AS MONEY

	SET @SumCourseUnits = [dbo].[fnStudentUnits](@StudentID)
	
	IF @SumCourseUnits > 9
	BEGIN
		SET @Tuition =
			(SELECT FullTimeCost + (@SumCourseUnits * PerUnitCost)
			FROM Students AS s
				JOIN StudentCourses AS sc
					ON s.StudentID = sc.StudentID
				JOIN Courses AS c
					ON sc.CourseID = c.CourseID
				CROSS JOIN Tuition
				WHERE s.StudentID = @StudentID
				GROUP BY s.StudentID, FullTimeCost, PerUnitCost)
	END

	ELSE IF @SumCourseUnits > 0 AND @SumCourseUnits <= 9
	BEGIN
		SET @Tuition =
			(SELECT PartTimeCost + (@SumCourseUnits * PerUnitCost)
			FROM Students AS s
				JOIN StudentCourses AS sc
					ON s.StudentID = sc.StudentID
				JOIN Courses AS c
					ON sc.CourseID = c.CourseID
				CROSS JOIN Tuition
				WHERE s.StudentID = @StudentID
				GROUP BY s.StudentID, PartTimeCost, PerUnitCost)
	END
	RETURN @Tuition
END

/***********************************************************************/
/* This is a trigger named tInstructors_UPDATE that checks the new value for the AnnualSalary column of the Instructors table.
/* This trigger raises an error if the salary is above 120000 or below 0
/* If the new annual salary is between 0 and 12,000, this trigger modifies the new annual salary by multiplying it by 12.
/* Monthly salaries become annual salaries this way 
************************************************************************/

CREATE TRIGGER tInstructors_UPDATE
ON Instructors
AFTER UPDATE
AS
IF EXISTS
	(SELECT *
	FROM deleted AS d 
		JOIN Instructors AS i
			ON d.InstructorID = i.InstructorID
	WHERE d.AnnualSalary <> i.AnnualSalary)
	BEGIN
	IF EXISTS
		(SELECT *
		FROM Instructors
		WHERE AnnualSalary > 120000 OR AnnualSalary < 0)
		BEGIN
			RAISERROR('AnnualSalary cannot be greater than 120000 or less than 0',16,1)
			ROLLBACK TRANSACTION;
		END;
	IF EXISTS
		(SELECT *
		FROM inserted
		WHERE AnnualSalary > 0 AND AnnualSalary < 12000)
		BEGIN
			UPDATE Instructors
			SET AnnualSalary = ins.AnnualSalary * 12
			FROM Instructors AS i
				JOIN inserted AS ins
					ON ins.InstructorID = i.InstructorID
			WHERE ins.InstructorID = i.InstructorID;
		END;
	END;

/***********************************************************************/
/* This is a trigger named tInstructors_INSERT that inserts the current date for the HireDate column of the Instructors table 
/* if the value for that column is null.
************************************************************************/

CREATE TRIGGER tInstructors_INSERT
ON Instructors
INSTEAD OF INSERT
AS
DECLARE @InstructorID int,
		@LastName varchar(25),
		@FirstName varchar(25),
		@Status char(1),
		@DepartmentChairman bit,
		@HireDate date,
		@AnnualSalary money,
		@DepartmentID int,
		@TestRowCount int;
SELECT @TestRowCount = COUNT(*) FROM inserted;
IF @TestRowCount = 1
	BEGIN
		SELECT @InstructorID = InstructorID,
			   @LastName = LastName,
			   @FirstName = FirstName,
			   @Status = Status,
			   @DepartmentChairman = DepartmentChairman,
			   @HireDate = HireDate,
			   @AnnualSalary = AnnualSalary,
			   @DepartmentID = DepartmentID
		FROM inserted;
		IF (@HireDate IS NULL)
			BEGIN
				SET @HireDate = CAST(CURRENT_TIMESTAMP AS DATE);
			END;
		INSERT Instructors
			(InstructorID, LastName, FirstName, Status, DepartmentChairman, HireDate, AnnualSalary, DepartmentID)
		VALUES (@InstructorID, @LastName, @FirstName, @Status, @DepartmentChairman, @HireDate, @AnnualSalary, @DepartmentID);
	END;
ELSE
	RAISERROR('Limit INSERT to a single row',16,1);
	
/***********************************************************************/
/* This is a script that determines if too few students (less than five) or too many students (greater than 10) are enrolled in each course, using a coursor.
/************************************************************************/

DECLARE @NumStudents INT;
DECLARE @CourseID INT;
DECLARE Student_Coursor CURSOR
FOR
	SELECT CourseID, COUNT(*) FROM StudentCourses
	GROUP BY CourseID;

OPEN Student_Coursor;

FETCH NEXT FROM Student_Coursor
	INTO @CourseID, @NumStudents;
WHILE @@FETCH_STATUS <> - 1
	BEGIN
		IF @NumStudents < 5
			PRINT 'There are too few students enrolled in CourseID ' + CAST(@CourseID AS VARCHAR(MAX));
		ELSE IF @NumStudents >= 5 AND @NumStudents <= 10
			PRINT 'There is an average amount of students enrolled in CourseID ' + CAST(@CourseID AS VARCHAR(MAX));
		ELSE IF @NumStudents > 10
			PRINT 'There are too many students enrolled in CourseID  ' + CAST(@CourseID AS VARCHAR(MAX));
		FETCH NEXT FROM Student_Coursor
			INTO @CourseID, @NumStudents;
	END;

CLOSE Student_Coursor;
DEALLOCATE Student_Coursor;

/***********************************************************************/
/* Ad hoc query that uses a CTE with a SELECT statement that returns one row for each student that has courses with these columns:
/* The StudentID column from the Students table
/* The sum of the course units in the Courses table
/* The statement then returns the StudentID, sum of course units for that student, whether they are a full-time or part-time student, and their tuition cost
************************************************************************/

WITH StuCourseCreds AS
(
 SELECT s.StudentID, SUM(CourseUnits) AS SumCourseUnits
 FROM Students AS s
	JOIN StudentCourses AS sc
		ON s.StudentID = sc.StudentID
	JOIN Courses AS c
		ON sc.CourseID = c.CourseID
GROUP BY s.StudentID
)
SELECT StudentID, SumCourseUnits, IIF(SumCourseUnits>9, 'Full Time', 'Part Time') AS StuStatus, IIF(SumCourseUnits>9, PerUnitCost*SumCourseUnits + FullTimeCost, PerUnitCost*SumCourseUnits + PartTimeCost) AS TuitionCost
FROM StuCourseCreds
CROSS JOIN Tuition;

/************************************************************************/
/* This is a script that creates a function, instead of using a CTE, named fnStudentUnits that calculates the total course units of a student in the StudentCourses table.
/************************************************************************/

CREATE FUNCTION fnStudentUnits
(
	@StudentID INT
)
RETURNS INT
AS
BEGIN

	DECLARE @SumCourseUnits AS INT

	SET @SumCourseUnits = 
		(SELECT SUM(CourseUnits)
		FROM StudentCourses AS sc
			JOIN Courses AS c
				ON sc.CourseID = c.CourseID
		WHERE StudentID = @StudentID)


	RETURN @SumCourseUnits

END
	
