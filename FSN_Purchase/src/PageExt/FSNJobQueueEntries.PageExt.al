pageextension 50152 "FSN Job Queue Entries Ext" extends "Job Queue Entries"
{
    layout
    {
        addafter(Description)
        {

            field("FSN HRC No"; "FSN HRC No")
            {
                ApplicationArea = All;
                Caption = 'No. Recepción';
                ToolTip = 'No. Recepción';
                trigger OnValidate()
                begin
                    // Add validation code here
                end;
            }
            field("FSN Order No"; "FSN Order No")
            {
                ApplicationArea = All;
                Caption = 'No. Pedido';
                ToolTip = 'No. Pedido';
                trigger OnValidate()
                begin
                    // Add validation code here
                end;
            }
            // Add more fields as needed
        }

    }
}