package app.atl.scanme;

import androidx.activity.ComponentActivity;
import androidx.activity.EdgeToEdge;

/**
 * Java call to {@link EdgeToEdge#enable} so Play Pre-launch sees the API
 * (Kotlin cannot import the {@code EdgeToEdge} file-facade type).
 */
final class PlayEdgeToEdge {
    private PlayEdgeToEdge() {}

    static void enable(ComponentActivity activity) {
        EdgeToEdge.enable(activity);
    }
}
