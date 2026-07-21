pageextension 50120 "FSN Retail Purchase Order" extends "LSC Retail Purchase Order"
{
    layout
    {
        addafter(Status)
        {

            field("Associated Credit Memo"; "Associated Credit Memo")
            {

            }

        }

    }

}
