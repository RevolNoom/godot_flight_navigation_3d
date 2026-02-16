# C# Best Practices

This document outlines the coding standards and best practices for C# development.

## Use LINQ methods instead of LINQ query expression.
### Example 1: 
#### Bad
IEnumerable<int> highScoresQuery =
    from score in scores
    where score > 80
    orderby score descending
    select score;

#### Good
var highScores = scores.Where(score => score > 80);
highScores = highScores.OrderByDescending(score => score);

## Refer to tuple items by their field name.
### Example 1: C#
#### Bad
var name = tupleData.Item1;
#### Good
var name = tupleData.name;

## SQL format
### Follow rules from best_practice_sql.md
### Use GetTableName(typeof(SomeClass)) instead of fixed string for table name
#### Example 1: 
##### Bad
var sql = $@"
SELECT *
FROM rp_report_list AS rrl";

##### Good
var sql = $@"
SELECT *
FROM {GetTableName(typeof(SysReportListEntity))} AS rrl";

### Use $@"" instead of concatenating multiple $""
#### Example 1: 
##### Bad
var sql = $"SELECT rrl.id, rrl.report_id" +
    $"FROM {GetTableName(typeof(SysReportListEntity))} rrl";

##### Good
var sql = $@"
SELECT
    rrl.{nameof(SysReportListEntity.id)} AS id,
    rrl.{nameof(SysReportListEntity.report_id)} AS report_id
FROM {GetTableName(typeof(SysReportListEntity))} AS rrl";

### Use nameof(SomeClass.property_name) instead of fixed string for column name
#### Example 1: 
##### Bad
var sql = $@"
SELECT
    rrl.id AS id,
    rrl.report_id AS report_id
FROM {GetTableName(typeof(SysReportListEntity))} AS rrl";

##### Good
var sql = $@"
SELECT
    rrl.{nameof(SysReportListEntity.id)} AS {nameof(SysReportListEntity.id)},
    rrl.{nameof(SysReportListEntity.report_id)} AS {nameof(SysReportListEntity.report_id)}
FROM {GetTableName(typeof(SysReportListEntity))} AS rrl";
