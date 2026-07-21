report 50010 "FSN RolloAuditor"
{
    DefaultLayout = RDLC;
    ApplicationArea = All;
    UsageCategory = Administration;
    
    RDLCLayout = 'Layout/RolloAuditor.rdl';

    dataset
    {
        dataitem("FSN Printing Copy"; "FSN Printing Copy")
        {
            column(LinePrinted; "FSN Printing Copy"."Line Printed")
            {
            }
            column(Wide; "FSN Printing Copy".Wide)
            {
            }
            column(Bold; "FSN Printing Copy".Bold)
            {
            }
            column(High; "FSN Printing Copy".High)
            {
            }
            column(Italic; "FSN Printing Copy".Italic)
            {
            }
        }
    }

    requestpage
    {

        layout
        {
        }

        actions
        {
        }
    }

    labels
    {
    }
}

