pageextension 50116 "FSN Purchase Prices" extends "Purchase Prices"
{
    layout
    {
        addafter("Direct Unit Cost")
        {
            field("FSN Costo despues de NC"; "FSN Cost After NC")
            {
                Caption = 'Costo despues de NC';
                trigger OnValidate()
                begin
                    if "FSN Cost After NC" < 0 then
                        Error('Este valor no puede ser negativo');

                    if "FSN Cost After NC" >= "Direct Unit Cost" then
                        Error('Este valor no puede ser mayor o igual al costo unitario');
                end;
            }
        }
    }
}