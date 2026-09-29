# Fundamentals of Parameter Sniffing

### Goals
1. Understand what parameter sniffing is (and is not)  
2. Analyze types of queries that are susceptible  
3. See what triggers sniffing emergencies  
4. How to react to emergencies  

#### Out of Scope (mastering class)  
* Capturing different plans  
* Prioritizing plan differences to fix  
* Mitigate sniffing with indexes, t-sql, database settings, server settings  




## What Parameter Sniffing Is  

#### Parameter Sniffing Is a Result of: 
1. Parameters
2. Different plans based on those parameters

A plan is cached based on the parameter values first passed in...SQL Server "sniffs" the parameter value before creating the plan, so it can create the best one. This is a good thing. The problem with parameter sniffing comes in when parameter values for edge cases are passed in, and the cached plan is bad for that scenario.

#### Memory Grants Affected by Parameter Sniffing
* If a proc is cached for a large set of data, and has a large memory grant  
-> When it runs for a small set of data, the memory grant is excessive, and SQL Server still clears out a large amount of cached data in memory to make room for the query  
* If a proc is first cached for a small set of data, it has a small memory grant  
-> When it runs for a large set of data, the memory grant is too small, and it spills to tempdb  




## Kinds of Queries That are Vulnerable

* SQL Server needs to be able to know what data is being used for the parameter  
-> Parameter is used in query  
-> Parameter does not have a scalar function on it...like UPPER()  
-> Values passed in for parameter return large and small sets of data  

#### Statistics Histogram
* Statistics only store info on 1 8k page, so it only uses up to 201 "buckets"  
-> values with lots of rows get their own bucket  
-> others get an average between bucket values  
-> this means you get inaccurate estimates for those in between values  
-> find outlier data by looking for values over #200 gouped by value, ordered by count(*)  
* Statistics innacurate is not a parameter sniffing problem...if statistics do not show how many rows, it is just an estimation problem  
-> improve by separating the query and put the first set of results into a temp table  


## Parameter sniffing requires two things:
1. Sniffed parameters, AND  
2. Different execution plans.  

The first one is easy. But what produces the second one? Decisions:  
#### WHERE:  
* How many rows will come out?  
#### SELECT:  
* What columns do we need, and which indexes have them?  
* Should we do an index seek w/key lookup, or a table scan?  
#### FROM, JOIN:  
* Which table should we process first?  
* How many rows will we find in the rest of the tables?  
* How will we access those tables: seek + key lookup, or scan?  
#### GROUP BY, ORDER BY:  
* How many rows will be involved?  
* How much memory should we grant? (How much data will we need to sort?)  
* How many threads should we use? (Meaning, how much work needs to be done?)  




## More Plan Choices, More Problems

* Adding an index can cause a parameter sniffing problem  
-> It might make a large data set efficient, but that plan cold be horrible for a small data set  
* Increase complexity of query  
-> more filtering clauses...the value for each one can affect which table filter is more seletive  
-> more parameters mean more combinations that can lead to different plans  

## How to look for it  
* Run the stored proc with recompile for a big and small outlier parameter values to see if they have different execution plans from common/medium values    





