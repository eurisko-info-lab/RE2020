# Formal Approximation Certificate

- profile: `empirical-float-real-bridge-v1`
- sourceFingerprint: `174319bb037f37434f9fc91c08c5675eb0691e90d2351598e53ec57e3679b7ae`
- corpus files: `1`
- indicator samples: `2`

## Epsilons

| metric | epsilon | maxAbsObserved | samples |
|---|---:|---:|---:|
| bbio | 2.82596521e-08 | 282.596521 | 2 |
| cep | 1.89586003e-08 | 189.586003 | 2 |
| cepNr | 1.56682647e-08 | 156.682647 | 2 |
| dh | 1e-09 | 0.886836 | 2 |

## Model

```
eps(metric) = max(absFloor, maxAbsObserved(metric) * relativeFactor)
```

- relativeFactor: `1e-10`
- absFloor: `1e-09`
