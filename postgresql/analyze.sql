
create table emp(eid int,name varchar(20),esal int);

select *from emp;
INSERT INTO emp (eid, name, esal)
SELECT
    x,
    'Employee-' || x,
    (20000 + random() * 80000)::int
FROM generate_series(1, 10000) AS x;


select *from emp;
select *from emp where esal>50000;

explain analyze 
select *from emp where esal>60000;

create index id on emp(esal);
EXPLAIN (ANALYZE,BUFFERS)
select *from emp where eid IN(11,12);

EXPLAIN (ANALYZE,BUFFERS)
select *from emp where esal>50000;


