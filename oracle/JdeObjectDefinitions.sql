/*
 * Objects and their Descriptions in JDE are stored in jdepd01.OL920.F9860 (Object Librarian Master Table). Here’s the query I used to pull your Table descriptions:
 * 
 * 
 */

SELECT siobnm, simd FROM ol920.f9860 WHERE siobnm IN ('F5501001', 'F5504001');
