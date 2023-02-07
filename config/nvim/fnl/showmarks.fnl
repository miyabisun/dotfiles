(fn get-marks [name]
  (vim.fn.getmarklist name))

(let [marks (ipairs (get-marks "%"))
      ns 0
      buf 0]
  (each [_ {:mark mark :pos [_ line _ _]} marks]
    (vim.api.nvim_buf_set_virtual_text buf, ns, line, [[mark WarningMsg]] "")))
