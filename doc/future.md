# future

## state transition diagram

```
         launch            finish
initial --------> running --------> ready
                   |   ^
           suspend |   | resume
                   v   |
                 suspended
```
