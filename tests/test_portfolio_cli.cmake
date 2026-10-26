function(reject)
  execute_process(COMMAND "${CLI}" ${ARGN} RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
  if(rc EQUAL 0 OR NOT err MATCHES "Error:")
    message(FATAL_ERROR "Expected explicit portfolio CLI failure: ${ARGN}; rc=${rc}; ${out}; ${err}")
  endif()
endfunction()
set(fixture "${SOURCE_DIR}/data/portfolio-two.txt")
reject(--portfolio "${fixture}" 0)
reject(--portfolio "${fixture}" 10000001)
reject(--portfolio "${fixture}" 17 -1)
reject(--portfolio "${fixture}" 17 18446744073709551616)
reject(--portfolio "${fixture}" 17 42 unexpected)
reject(--portfolio "${fixture}" --backend cuda --cuda-mode hybrid --batch-size 0)
set(bad "${CMAKE_CURRENT_BINARY_DIR}/invalid-portfolio.txt")
foreach(contents IN ITEMS
    "portfolio-v1 USD 1 0"
    "portfolio-v1 USD 1 6"
    "portfolio-v1 USD -1 1\nA 1 100 .05 .2\n1"
    "portfolio-v1 USD 1 1\nA 1 100 .05 .2\n1 trailing"
    "portfolio-v1 USD 1 2\nA 1 100 .05 .2\nA 1 100 .05 .2\n1 0 0 1"
    "portfolio-v1 USD 1 2\nA 1 100 .05 .2\nB 1 100 .05 .2\n1 .6"
    "portfolio-v1 USD 1 1\nA 1 100 .05 nan\n1"
    "portfolio-v1 USD 1 1\nA 1 100 .05 .2\ninf")
  file(WRITE "${bad}" "${contents}\n")
  reject(--portfolio "${bad}" 17 42 --json)
endforeach()
