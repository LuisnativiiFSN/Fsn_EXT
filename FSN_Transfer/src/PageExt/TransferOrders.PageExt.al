pageextension 50170 "FSN Transfer Orders" extends "Transfer Orders"
{
    layout
    {
        addafter("In-Transit Code")
        {
            field("Posting Date"; "Posting Date")
            {

            }
        }
    }
}