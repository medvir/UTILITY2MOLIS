# Utility2MOLIS
Shiny app which takes the export of an SARS-CoV-2 E-Gen Cobas Utility run and returns a readable pdf report.

Channel 2 is assumed to be E-Gene, channel 5 internal control. If there's another value present in this column, it is interpreted as `NA`.

## Result interpretation
**Positive** if ct value of E-gene is < 45.  
TODO: independant of the IC result?  

**Negative** if internal control (IC) is valid (ct value between 30 and 40) AND ct value of E-gene could not be detected (NA).  

**Invalid** neither positive nor negative  
TODO: a sample would be interpreted as invalid if ct value of E-gene is >=45, could that happen?  

## TODO
Ev. noch eine Kontrolle, dass die Positivkontrolle im E-Gen positiv ist. Die Positivkontrolle ist von uns und hat wohl in irgendwie “pos” im Namen oder sonst einfach das sample, das keine MOLIS-Nummer oder keine Nummer in der Art “C161420284112853995982" (Negativkontrolle von Roche) ist.
