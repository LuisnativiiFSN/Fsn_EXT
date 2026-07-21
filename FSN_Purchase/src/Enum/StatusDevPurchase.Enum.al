enum 50099 "FSN Status Purchase Dev"
{
    Extensible = true;

    value(0; None)
    {
    }
    value(1; returned)
    {
        Caption = 'Rechazado';
    }
    value(2; Solved)
    {
        Caption = 'Solventado';
    }
}