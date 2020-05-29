package deckers.thibault.aves.utils;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Environment;

import androidx.annotation.NonNull;

public class Env {
    private static String[] mStorageVolumeRoots;
    private static String mExternalStorage;
    // SD card path as a content URI from the Documents Provider
    // e.g. content://com.android.externalstorage.documents/tree/12A9-8B42%3A
    private static String mSdCardDocumentUri;

    private static final String PREF_SD_CARD_DOCUMENT_URI = "sd_card_document_uri";

    public static void setSdCardDocumentUri(final Activity activity, String SdCardDocumentUri) {
        mSdCardDocumentUri = SdCardDocumentUri;
        SharedPreferences.Editor preferences = activity.getPreferences(Context.MODE_PRIVATE).edit();
        preferences.putString(PREF_SD_CARD_DOCUMENT_URI, mSdCardDocumentUri);
        preferences.apply();
    }

    public static String getSdCardDocumentUri(final Activity activity) {
        if (mSdCardDocumentUri == null) {
            SharedPreferences preferences = activity.getPreferences(Context.MODE_PRIVATE);
            mSdCardDocumentUri = preferences.getString(PREF_SD_CARD_DOCUMENT_URI, null);
        }
        return mSdCardDocumentUri;
    }

    public static String[] getStorageVolumeRoots(final Activity activity) {
        if (mStorageVolumeRoots == null) {
            mStorageVolumeRoots = StorageUtils.getStorageVolumeRoots(activity);
        }
        return mStorageVolumeRoots;
    }

    private static String getExternalStorage() {
        if (mExternalStorage == null) {
            mExternalStorage = Environment.getExternalStorageDirectory().getAbsolutePath();
            if (!mExternalStorage.endsWith("/")) {
                mExternalStorage += "/";
            }
        }
        return mExternalStorage;
    }

    public static boolean requireAccessPermission(@NonNull String path) {
        boolean onPrimaryVolume = path.startsWith(getExternalStorage());
        // TODO TLAD on Android R, we should require access permission even on primary
        return !onPrimaryVolume;
    }
}
