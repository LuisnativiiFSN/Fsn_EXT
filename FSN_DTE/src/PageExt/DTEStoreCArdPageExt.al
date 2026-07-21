pageextension 50044 "FSN DTE Store Page Ext" extends "LSC Store Card"
{
    layout
    {
        addafter(General)
        {
            group("DTE")
            {
                field("DTE TypeEstablishment"; "DTE TypeEstablishment") { }
                field("DTE CodeEstablishment"; "DTE CodeEstablishment") { }
                field("DTE CodeEstablishmentMH"; "DTE CodeEstablishmentMH") { }
            }
        }
    }
    actions
    {
    }
}