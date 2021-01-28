library(magrittr)

datas <- seq(as.Date("2020-01-01"), as.Date("2021-01-01"), by = 1)
path_cjsg <- "/mnt/dados/abj/tjsp/cjsg/2020/"
purrr::walk(datas, ~{
  dir_dia <- sprintf("%s%s", path_cjsg, as.character(.x))
  res <- ""
  if (!dir.exists(dir_dia)) {
    message(.x)
    safe <- purrr::possibly(lex::tjsp_cjsg_download, NULL)
    res <- safe("", dir_dia, julgamento_ini = .x, julgamento_fim = .x, sleep = 1)
  }
  res
})

