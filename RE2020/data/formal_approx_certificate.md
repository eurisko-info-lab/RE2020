# Formal Approximation Certificate

- profile: `empirical-float-real-bridge-v1`
- sourceFingerprint: `f044517581acdca1aacba18e7a2418ad3721c10744a8b432b7842231e0f1f602`
- corpus files: `15`
- indicator samples: `45`

## Epsilons

| metric | epsilon | maxAbsObserved | samples |
|---|---:|---:|---:|
| bbio | 1.18873366e-08 | 118.873366 | 45 |
| cep | 1.04476212e-08 | 104.476212 | 45 |
| cepNr | 9.16458e-09 | 91.6458 | 45 |
| dh | 1e-09 | 0 | 45 |

## Model

```
eps(metric) = max(absFloor, maxAbsObserved(metric) * relativeFactor)
```

- relativeFactor: `1e-10`
- absFloor: `1e-09`
