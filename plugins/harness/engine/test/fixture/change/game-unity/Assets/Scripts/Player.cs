public class Player : MonoBehaviour {
    public float speed = 5f;
    public const int Max = 3;
    void Update() {
        var cam = Camera.main;
        var gm = GameObject.Find("GameManager");
        Debug.Log("tick");
    }
}
