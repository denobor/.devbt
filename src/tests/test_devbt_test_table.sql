/*****************************************************************************************
  test the test table to see if it was created correctly
  this: {{ this }}

*****************************************************************************************/


select * from {{ ref("devbt_test_table") }} where result != 'PASSED'
